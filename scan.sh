#!/bin/bash

# ==================================================
# ⚙️ AYARLAR VE PROFİLLER
# ==================================================
ANA_KLASOR="/mnt/HDD_Ana/tarattiklarim" # Varsayılan ana klasör, istersen değiştirebilirsin
HEDEF_KLASOR="$ANA_KLASOR/ham_tiff"
ZAMAN=$(date +"%Y%m%d_%H%M%S")
DOSYA="$HEDEF_KLASOR/scan_$ZAMAN.tiff"
JSON_DOSYA="$HEDEF_KLASOR/scan_$ZAMAN.json"
PREVIEW_DOSYA="/tmp/preview_$ZAMAN.tiff"

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PYTHON_BUL="$SCRIPT_DIR/otomatik_sinir_bul.py"
DURUM_DOSYASI="$HOME/scan_status.txt"

mkdir -p "$HEDEF_KLASOR"

PARAM_PROFIL=$1
PARAM_DPI=$2
PARAM_OZEL_X=$3
PARAM_OZEL_Y=$4

if [ -n "$PARAM_PROFIL" ] && [ -n "$PARAM_DPI" ]; then
    SECIM=$PARAM_PROFIL
    SECILEN_DPI=$PARAM_DPI
    if [ "$SECIM" -eq 2 ] && [ -n "$PARAM_OZEL_X" ] && [ -n "$PARAM_OZEL_Y" ]; then
        SECILEN_X=$PARAM_OZEL_X
        SECILEN_Y=$PARAM_OZEL_Y
    fi
else
    echo "=================================================="
    echo "🖨️  TARAMA PROFİLİ SEÇİMİ"
    echo "=================================================="
    echo "  1) Otomatik (Önizleme yapar, fotoğrafları bulur ve sadece o alanı tarar)"
    echo "  2) Özel Ölçü (Manuel X ve Y girilir)"
    echo ""
    read -p "👉 Profil seçin (1/2) [Varsayılan: 1]: " SECIM
    SECIM=${SECIM:-1}

    if [ "$SECIM" -eq 2 ]; then
        read -p "   Genişlik (X) mm [Varsayılan: 215]: " OZEL_X
        read -p "   Yükseklik (Y) mm [Varsayılan: 297]: " OZEL_Y
        SECILEN_X=${OZEL_X:-215}
        SECILEN_Y=${OZEL_Y:-297}
    fi

    echo ""
    echo "  1) 300 DPI | 2) 600 DPI | 3) 1200 DPI [Varsayılan]"
    read -p "👉 DPI seçin (1/2/3) [Varsayılan: 3]: " DPI_SECIM
    DPI_SECIM=${DPI_SECIM:-3}
    case $DPI_SECIM in
        1) SECILEN_DPI=300 ;;
        2) SECILEN_DPI=600 ;;
        *) SECILEN_DPI=1200 ;;
    esac
fi

YAZICI_ID="hpaio:/usb/Officejet_5600_series?serial=CN65VDF85704B2"

if [ "$SECIM" -eq 1 ]; then
    echo "⏳ Önizleme Taraması Yapılıyor..." > "$DURUM_DOSYASI"
    echo ">>> 1. Hızlı Önizleme Taraması Yapılıyor (75 DPI)..."
    scanimage -d "$YAZICI_ID" --format=tiff --mode=Color --resolution=75 -l 0 -t 0 -x 215 -y 297 > "$PREVIEW_DOSYA" 2>/dev/null
    
    echo ">>> 2. Fotoğraf Sınırları Hesaplanıyor..."
    COORDS=$(python3 "$PYTHON_BUL" "$PREVIEW_DOSYA" "$JSON_DOSYA")
    read SCAN_L SCAN_T SCAN_X SCAN_Y <<< "$COORDS"
    
    rm -f "$PREVIEW_DOSYA"
    PROFIL_AD="Otomatik Algılama"
else
    SCAN_L=0
    SCAN_T=0
    SCAN_X=$SECILEN_X
    SCAN_Y=$SECILEN_Y
    PROFIL_AD="Özel Ölçü (${SCAN_X}x${SCAN_Y} mm)"
fi

echo "⏳ Asıl Tarama Başlıyor... ($SECILEN_DPI DPI)" > "$DURUM_DOSYASI"
echo "=================================================="
echo ">>> 3. ASIL TARAMA BAŞLIYOR ($SECILEN_DPI DPI)"
echo ">>> Tarama Alanı: Sol=$SCAN_L, Üst=$SCAN_T, Genişlik=$SCAN_X, Yükseklik=$SCAN_Y"
echo "=================================================="

scanimage -d "$YAZICI_ID" \
  --format=tiff \
  --mode=Color \
  --resolution=$SECILEN_DPI \
  -l $SCAN_L -t $SCAN_T -x $SCAN_X -y $SCAN_Y \
  --progress 2>&1 > "$DOSYA" | tr '\r' '\n' | awk '/Progress:/ {printf "\r%s", $0; fflush()}'

echo ""

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    BOYUT=$(du -h "$DOSYA" | cut -f1)
    echo "✅ Kaydedildi: $DOSYA ($BOYUT)"
    echo "✅ Bitti. Son Kayıt: scan_$ZAMAN.tiff ($BOYUT)" > "$DURUM_DOSYASI"
else
    echo "❌ HATA: Tarama başarısız!"
    echo "❌ HATA: Tarayıcı bağlantısını kontrol edin!" > "$DURUM_DOSYASI"
fi