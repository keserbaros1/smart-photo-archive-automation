import sys
import os
from PIL import Image

# Çok büyük TIFF dosyaları için PIL'in güvenlik sınırını kaldıralım
Image.MAX_IMAGE_PIXELS = None

PROFILLER = {
    "otomatik": [], # JSON dosyasından dinamik okunacak
    "iki_buyuk_iki_kucuk": [
        {"ad": "sol_ust", "x": 0.00, "y": 0.00, "w": 0.48, "h": 0.51},
        {"ad": "sag_ust", "x": 0.52, "y": 0.00, "w": 0.48, "h": 0.51},
        {"ad": "sol_alt", "x": 0.00, "y": 0.57, "w": 0.48, "h": 0.43},
        {"ad": "sag_alt", "x": 0.52, "y": 0.57, "w": 0.48, "h": 0.43},
    ],
    "iki_buyuk": [
        {"ad": "foto_1", "x": 0.00, "y": 0.00, "w": 0.48, "h": 1},
        {"ad": "foto_2", "x": 0.52, "y": 0.00, "w": 0.48, "h": 1},
    ]
}

def islem_yap(dosya_yolu, cikis_klasoru, profil_adi, kesilsin_mi="E"):
    print(f"🔪 Kesiliyor (Pillow): {dosya_yolu}")
    try:
        img = Image.open(dosya_yolu)
        icc_profili = img.info.get('icc_profile')
    except Exception as e:
        print(f"   ❌ Hata: Fotoğraf açılamadı! ({e})")
        sys.exit(1)

    dosya_adi = os.path.splitext(os.path.basename(dosya_yolu))[0]

    if kesilsin_mi.lower() != 'e':
        print("   > 🔄 Kesim atlandı, geçici kopya oluşturuluyor...")
        hedef_yol = os.path.join(cikis_klasoru, f"{dosya_adi}_tam.png")
        img.save(hedef_yol, 'PNG', icc_profile=icc_profili)
        return

    w_img, h_img = img.size
    
    # OTOMATİK PROFİL İSE JSON DOSYASINI OKU
    if profil_adi == "otomatik":
        json_yolu = dosya_yolu.replace('.tiff', '.json')
        if os.path.exists(json_yolu):
            import json
            with open(json_yolu, 'r') as f:
                secilen_profil = json.load(f)
            print(f"   > 📐 Otomatik sınırlar algılandı ({len(secilen_profil)} fotoğraf)")
        else:
            print("   > ⚠️ JSON bulunamadı, fotoğraf tam sayfa olarak bırakılacak.")
            secilen_profil = [{"ad": "tam_sayfa", "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0}]
    else:
        secilen_profil = PROFILLER.get(profil_adi)

    if not secilen_profil:
        print(f"   ❌ Hata: '{profil_adi}' adında bir profil bulunamadı!")
        sys.exit(1)

    for b in secilen_profil:
        sol = int(b["x"] * w_img)
        ust = int(b["y"] * h_img)
        sag = int((b["x"] + b["w"]) * w_img)
        alt = int((b["y"] + b["h"]) * h_img)
        
        # Sınırları aşmamak için güvenlik kontrolü
        sag = min(sag, w_img)
        alt = min(alt, h_img)

        parca = img.crop((sol, ust, sag, alt))
        hedef_yol = os.path.join(cikis_klasoru, f"{dosya_adi}_{b['ad']}.png")
        parca.save(hedef_yol, 'PNG', icc_profile=icc_profili)

if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--list-profiles":
        print(" ".join(PROFILLER.keys()))
        sys.exit(0)
    elif len(sys.argv) == 2 and sys.argv[1] == "--default-profile":
        print(list(PROFILLER.keys())[0])
        sys.exit(0)
    elif len(sys.argv) >= 4:
        kes = sys.argv[4] if len(sys.argv) > 4 else "E"
        islem_yap(sys.argv[1], sys.argv[2], sys.argv[3], kes)
    else:
        print("Kullanım: python3 sabit_kirp.py <dosya_yolu> <cikis_klasoru> <profil_adi> [E/H]")
        sys.exit(1)
