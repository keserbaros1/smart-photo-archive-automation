#!/bin/bash

# ==================================================
# 🛡️ YETKİ KONTROLÜ
# ==================================================
if [ "$EUID" -ne 0 ]; then
  echo "❌ Lütfen betiği sudo ile çalıştırın: sudo bash $0"
  exit 1
fi

# Asıl kullanıcının ID'leri (sudo ile çalıştırıldığı için dosyaların root sahipliğinde olmaması için)
ASIL_UID=${SUDO_UID:-$(id -u)}
ASIL_GID=${SUDO_GID:-$(id -g)}
ASIL_USER=${SUDO_USER:-$USER}

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PYTHON_KES="$SCRIPT_DIR/sabit_kirp.py"
PYTHON_DONDUR="$SCRIPT_DIR/yuz_dondur.py"

echo "=================================================="
echo "🛠️  GEREKSİNİMLER KONTROL EDİLİYOR..."
echo "=================================================="
# Gerekli paketlerin listesi
PAKETLER="cifs-utils libavif-bin libheif-examples python3-opencv python3-pil"
EKSIKLER=""

for pkg in $PAKETLER; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        EKSIKLER="$EKSIKLER $pkg"
    fi
done

if [ -n "$EKSIKLER" ]; then
    echo "📦 Eksik paketler kuruluyor:$EKSIKLER"
    apt-get update
    apt-get install -y $EKSIKLER
    echo "✅ Paket kurulumları tamamlandı."
else
    echo "✅ Tüm gereksinimler zaten kurulu."
fi

echo ""
echo "=================================================="
echo "⚙️  AYARLAR VE TERCİHLER"
echo "=================================================="

read -p "📂 Kaynak neresi? (1: Yerel Klasör, 2: Ağ/SMB) [Varsayılan: 2]: " KAYNAK_TIP
KAYNAK_TIP=${KAYNAK_TIP:-2}

if [ "$KAYNAK_TIP" == "2" ]; then
    while true; do
        read -p "🌐 Ağ adresini girin (Örn: //{sunucu_adresi}/tarattiklarim/ham_tiff): " AG_ADRESI
        if [ -z "$AG_ADRESI" ]; then
            echo "❌ Ağ adresi boş olamaz! Lütfen tekrar deneyin."
            continue
        fi
        
        # Adresi parçala (//IP/PAYLASIM ve /ALT_KLASOR)
        AG_ADRESI=${AG_ADRESI%/} # Sondaki slash'i kaldır
        SHARE_PATH=$(echo "$AG_ADRESI" | cut -d'/' -f1-4)
        SUB_DIR=$(echo "$AG_ADRESI" | cut -d'/' -f5-)
        
        MOUNT_DIR=$(mktemp -d /mnt/foto_islem_XXXXXX)
        echo "🔗 Ağ sürücüsü bağlanıyor: $SHARE_PATH -> $MOUNT_DIR"
        mount -t cifs "$SHARE_PATH" "$MOUNT_DIR" -o rw,guest,uid=$ASIL_UID,gid=$ASIL_GID,dir_mode=0777,file_mode=0777
        if [ $? -ne 0 ]; then
            echo "❌ Bağlantı hatası! Ağ adresini kontrol edin."
            rmdir "$MOUNT_DIR"
            continue
        fi
        
        echo "✅ Kaynak bağlantısı başarılı!"
        if [ -n "$SUB_DIR" ]; then
            GIRIS_KLASOR="$MOUNT_DIR/$SUB_DIR"
        else
            GIRIS_KLASOR="$MOUNT_DIR"
        fi
        break
    done
else
    while true; do
        read -p "📁 Yerel klasör yolunu girin: " GIRIS_KLASOR
        if [ ! -d "$GIRIS_KLASOR" ]; then
            echo "❌ Belirtilen klasör bulunamadı: $GIRIS_KLASOR. Lütfen tekrar deneyin."
            continue
        fi
        break
    done
fi

while true; do
    read -p "🎯 Hedef klasör neresi olsun? (Örn: /home/$ASIL_USER/islenmisler veya //{sunucu_adresi}/arsiv): " HEDEF_GIRIS
    if [ -z "$HEDEF_GIRIS" ]; then
        echo "❌ Hedef klasör boş olamaz! Lütfen tekrar deneyin."
        continue
    fi

    # Hedef klasör ağ adresi mi kontrol et
    if [[ "$HEDEF_GIRIS" == //* ]]; then
        HEDEF_GIRIS=${HEDEF_GIRIS%/}
        HEDEF_SHARE=$(echo "$HEDEF_GIRIS" | cut -d'/' -f1-4)
        HEDEF_SUB=$(echo "$HEDEF_GIRIS" | cut -d'/' -f5-)
        
        HEDEF_MOUNT_DIR=$(mktemp -d /mnt/foto_hedef_XXXXXX)
        echo "🔗 Hedef ağ sürücüsü bağlanıyor: $HEDEF_SHARE -> $HEDEF_MOUNT_DIR"
        mount -t cifs "$HEDEF_SHARE" "$HEDEF_MOUNT_DIR" -o rw,guest,uid=$ASIL_UID,gid=$ASIL_GID,dir_mode=0777,file_mode=0777
        if [ $? -ne 0 ]; then
            echo "❌ Hedef bağlantı hatası! Ağ adresini kontrol edin."
            rmdir "$HEDEF_MOUNT_DIR"
            continue
        fi
        
        echo "✅ Hedef bağlantısı başarılı!"
        if [ -n "$HEDEF_SUB" ]; then
            HEDEF_ANA_KLASOR="$HEDEF_MOUNT_DIR/$HEDEF_SUB"
        else
            HEDEF_ANA_KLASOR="$HEDEF_MOUNT_DIR"
        fi
        break
    else
        HEDEF_ANA_KLASOR="$HEDEF_GIRIS"
        break
    fi
done

read -p "💾 İşlenen orijinal fotoğraflar arşive taşınsın mı? (E/h) [Varsayılan: E]: " TASINSIN_MI
TASINSIN_MI=${TASINSIN_MI:-E}

read -p "📅 Başlangıç Tarihi (YYYYMMDD_HHMMSS) [Varsayılan: 20000101_000000]: " BASLANGIC
BASLANGIC=${BASLANGIC:-20000101_000000}

read -p "📅 Bitiş Tarihi (YYYYMMDD_HHMMSS) [Varsayılan: 20991231_235959]: " BITIS
BITIS=${BITIS:-20991231_235959}

read -p "✂️  Fotoğraflar kesilsin mi? (E/h) [Varsayılan: E]: " KESILSIN_MI
KESILSIN_MI=${KESILSIN_MI:-E}

VARSAYILAN_PROFIL=$(python3 "$PYTHON_KES" --default-profile)
PROFIL="$VARSAYILAN_PROFIL"
if [[ "$KESILSIN_MI" =~ ^[Ee]$ ]]; then
    echo "   Mevcut Kesim Profilleri:"
    # Profilleri Python dosyasından dinamik olarak çek
    PROFILLER=($(python3 "$PYTHON_KES" --list-profiles))
    
    for i in "${!PROFILLER[@]}"; do
        echo "   $((i+1))) ${PROFILLER[$i]}"
    done
    
    read -p "   Profil seçin (1-${#PROFILLER[@]}) [Varsayılan: 1]: " PROFIL_SECIM
    PROFIL_SECIM=${PROFIL_SECIM:-1}
    
    # Seçilen profili al (dizi indeksi 0'dan başladığı için -1 yapıyoruz)
    SECILEN_INDEX=$((PROFIL_SECIM-1))
    if [ $SECILEN_INDEX -ge 0 ] && [ $SECILEN_INDEX -lt ${#PROFILLER[@]} ]; then
        PROFIL="${PROFILLER[$SECILEN_INDEX]}"
    else
        echo "   ⚠️ Geçersiz seçim, varsayılan profil ($VARSAYILAN_PROFIL) kullanılacak."
        PROFIL="$VARSAYILAN_PROFIL"
    fi
fi

read -p "🔄 Yüz tanıma ile otomatik döndürme yapılsın mı? (E/h) [Varsayılan: E]: " DONDURULSUN_MU
DONDURULSUN_MU=${DONDURULSUN_MU:-E}

read -p "📦 Sıkıştırma formatı (1: AVIF, 2: HEIC) [Varsayılan: 1]: " FORMAT_SECIM
FORMAT_SECIM=${FORMAT_SECIM:-1}

read -p "📉 Sıkıştırma kalitesi (1: Kayıpsız/Lossless, 2: Kayıplı/Lossy) [Varsayılan: 1]: " KALITE_SECIM
KALITE_SECIM=${KALITE_SECIM:-1}

KALITE_PARAM=""
if [ "$KALITE_SECIM" == "2" ]; then
    if [ "$FORMAT_SECIM" == "2" ]; then
        # HEIC Kayıplı
        echo "   HEIC Kayıplı Kalite Seçenekleri:"
        echo "   1) Yüksek Kalite (-q 90)"
        echo "   2) Orta Kalite (-q 70)"
        echo "   3) Düşük Kalite (-q 50)"
        read -p "   Seçiminiz (1/2/3) [Varsayılan: 1]: " HEIC_KALITE
        HEIC_KALITE=${HEIC_KALITE:-1}
        case $HEIC_KALITE in
            1) KALITE_PARAM="-q 90" ;;
            2) KALITE_PARAM="-q 70" ;;
            3) KALITE_PARAM="-q 50" ;;
            *) KALITE_PARAM="-q 90" ;;
        esac
    else
        # AVIF Kayıplı
        echo "   AVIF Kayıplı Kalite Seçenekleri:"
        echo "   1) Yüksek Kalite (--min 10 --max 20)"
        echo "   2) Orta Kalite (--min 20 --max 40)"
        echo "   3) Düşük Kalite (--min 40 --max 60)"
        read -p "   Seçiminiz (1/2/3) [Varsayılan: 1]: " AVIF_KALITE
        AVIF_KALITE=${AVIF_KALITE:-1}
        case $AVIF_KALITE in
            1) KALITE_PARAM="--min 10 --max 20" ;;
            2) KALITE_PARAM="--min 20 --max 40" ;;
            3) KALITE_PARAM="--min 40 --max 60" ;;
            *) KALITE_PARAM="--min 10 --max 20" ;;
        esac
    fi
fi

echo "⚡ Sıkıştırma Hızı Seçenekleri:"
echo "1) Yavaş (Daha iyi sıkıştırma, daha uzun sürer) [Varsayılan]"
echo "2) Orta"
echo "3) Hızlı (Daha az sıkıştırma, daha kısa sürer)"
read -p "Seçiminiz (1/2/3) [Varsayılan: 1]: " HIZ_SECIM
HIZ_SECIM=${HIZ_SECIM:-1}

HIZ_PARAM=""
if [ "$FORMAT_SECIM" == "2" ]; then
    # HEIC Hız
    case $HIZ_SECIM in
        1) HIZ_PARAM="-p preset=slow" ;;
        2) HIZ_PARAM="-p preset=medium" ;;
        3) HIZ_PARAM="-p preset=fast" ;;
        *) HIZ_PARAM="-p preset=slow" ;;
    esac
else
    # AVIF Hız
    case $HIZ_SECIM in
        1) HIZ_PARAM="--speed 2" ;; # AVIF'te düşük sayı daha yavaş/iyi
        2) HIZ_PARAM="--speed 4" ;;
        3) HIZ_PARAM="--speed 8" ;;
        *) HIZ_PARAM="--speed 2" ;;
    esac
fi

# Klasörleri oluştur
CIKIS_KLASOR="$HEDEF_ANA_KLASOR/cikti_foto"
COP_KLASOR="$HEDEF_ANA_KLASOR/arsiv_raw"

echo "📁 Hedef klasörler oluşturuluyor..."
mkdir -p "$CIKIS_KLASOR"
chown $ASIL_UID:$ASIL_GID "$CIKIS_KLASOR"

if [[ "$TASINSIN_MI" =~ ^[Ee]$ ]]; then
    mkdir -p "$COP_KLASOR"
    chown $ASIL_UID:$ASIL_GID "$COP_KLASOR"
fi

# Özel TMP klasörü (Çakışmaları ve veri kaybını önlemek için)
TMP_ISLEM=$(mktemp -d /tmp/foto_islem_XXXXXX)
chown $ASIL_UID:$ASIL_GID "$TMP_ISLEM"

echo ""
echo "=================================================="
echo "🚀 İŞLEM BAŞLIYOR..."
echo "=================================================="

# Dosyaları isimlerine göre sıralı şekilde al
for dosya in $(ls "$GIRIS_KLASOR"/scan_*.tiff 2>/dev/null | sort); do
    DOSYA_ADI=$(basename "$dosya" .tiff)
    ZAMAN_DAMGASI=${DOSYA_ADI#scan_}

    if [[ ! "$ZAMAN_DAMGASI" < "$BASLANGIC" && ! "$ZAMAN_DAMGASI" > "$BITIS" ]]; then
        echo "------------------------------------------------"
        echo "▶ İşleniyor: $DOSYA_ADI"
        
        KESIM_BASARILI=1
        
        # 1. ADIM: KESİM VEYA KOPYALAMA
        if [[ "$KESILSIN_MI" =~ ^[Ee]$ ]]; then
            sudo -u $ASIL_USER python3 "$PYTHON_KES" "$dosya" "$TMP_ISLEM" "$PROFIL" "E"
            KESIM_BASARILI=$?
        else
            # Kesilmeyecekse, yüz döndürme ve sıkıştırma için geçici PNG oluştur
            sudo -u $ASIL_USER python3 "$PYTHON_KES" "$dosya" "$TMP_ISLEM" "yok" "H"
            KESIM_BASARILI=$?
        fi
        
        if [ $KESIM_BASARILI -eq 0 ]; then
            for png_parca in "$TMP_ISLEM"/${DOSYA_ADI}_*.png; do
                if [ -f "$png_parca" ]; then
                    PARCA_ADI=$(basename "$png_parca" .png)
                    
                    # 2. ADIM: YÜZ TANIMA VE DÖNDÜRME
                    if [[ "$DONDURULSUN_MU" =~ ^[Ee]$ ]]; then
                        sudo -u $ASIL_USER python3 "$PYTHON_DONDUR" "$png_parca"
                    fi
                    
                    # 3. ADIM: SIKIŞTIRMA
                    if [ "$FORMAT_SECIM" == "2" ]; then
                        HEDEF_DOSYA="$CIKIS_KLASOR/${PARCA_ADI}.heic"
                        if [ "$KALITE_SECIM" == "1" ]; then
                            echo "   > 📦 HEIC (Kayıpsız) Sıkıştırılıyor: $PARCA_ADI"
                            sudo -u $ASIL_USER heif-enc --lossless $HIZ_PARAM "$png_parca" -o "$HEDEF_DOSYA" > /dev/null 2>&1
                        else
                            echo "   > 📦 HEIC (Kayıplı) Sıkıştırılıyor: $PARCA_ADI"
                            sudo -u $ASIL_USER heif-enc $KALITE_PARAM $HIZ_PARAM "$png_parca" -o "$HEDEF_DOSYA" > /dev/null 2>&1
                        fi
                    else
                        HEDEF_DOSYA="$CIKIS_KLASOR/${PARCA_ADI}.avif"
                        if [ "$KALITE_SECIM" == "1" ]; then
                            echo "   > 📦 AVIF (Kayıpsız) Sıkıştırılıyor: $PARCA_ADI"
                            sudo -u $ASIL_USER avifenc --lossless $HIZ_PARAM "$png_parca" "$HEDEF_DOSYA" > /dev/null 2>&1
                        else
                            echo "   > 📦 AVIF (Kayıplı) Sıkıştırılıyor: $PARCA_ADI"
                            sudo -u $ASIL_USER avifenc $HIZ_PARAM $KALITE_PARAM "$png_parca" "$HEDEF_DOSYA" > /dev/null 2>&1
                        fi
                    fi
                    
                    # İşlenen geçici PNG'yi sil
                    rm -f "$png_parca"
                fi
            done
            
            # 4. ADIM: ORİJİNALİ ARŞİVE TAŞI
            if [[ "$TASINSIN_MI" =~ ^[Ee]$ ]]; then
                echo "   > 💾 Orijinal TIFF arşive kaldırılıyor..."
                mv -f "$dosya" "$COP_KLASOR/"
                
                # Varsa JSON dosyasını da arşive taşı
                JSON_DOSYA="${dosya%.tiff}.json"
                if [ -f "$JSON_DOSYA" ]; then
                    mv -f "$JSON_DOSYA" "$COP_KLASOR/"
                fi
            fi
            echo "   ✅ İşlem Tamam!"
        else
            echo "   ❌ İşlem hatası oluştu, dosya atlandı."
        fi
    fi
done

echo "=================================================="
echo "🧹 TEMİZLİK YAPILIYOR..."
echo "=================================================="
rm -rf "$TMP_ISLEM"

if [ "$KAYNAK_TIP" == "2" ] && [ -n "$MOUNT_DIR" ]; then
    echo "🔌 Kaynak ağ sürücüsü bağlantısı kesiliyor..."
    umount "$MOUNT_DIR"
    rmdir "$MOUNT_DIR"
fi

if [[ "$HEDEF_GIRIS" == //* ]] && [ -n "$HEDEF_MOUNT_DIR" ]; then
    echo "🔌 Hedef ağ sürücüsü bağlantısı kesiliyor..."
    umount "$HEDEF_MOUNT_DIR"
    rmdir "$HEDEF_MOUNT_DIR"
fi

echo "🎉 TÜM İŞLEMLER BİTTİ!"
