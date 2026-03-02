import cv2
import sys
import json
import numpy as np

def bul(preview_yolu, json_yolu):
    img = cv2.imread(preview_yolu)
    if img is None:
        print("0 0 215 297") # Hata olursa tüm A4'ü tara
        return
        
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Arka planı beyaz kabul edip, koyu bölgeleri (fotoğrafları) buluyoruz
    blurred = cv2.GaussianBlur(gray, (11, 11), 0)
    _, thresh = cv2.threshold(blurred, 220, 255, cv2.THRESH_BINARY_INV)
    
    # Morfolojik işlemler (küçük tozları yok et, fotoğrafları birleştir)
    kernel = np.ones((15,15), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    img_h, img_w = img.shape[:2]
    A4_W_MM = 215.0
    A4_H_MM = 297.0
    
    fotolar = []
    for c in contours:
        x, y, w, h = cv2.boundingRect(c)
        alan = w * h
        # En az %2'lik bir alan kaplamalı (Ufak tefek tozları yoksay)
        if alan > (img_w * img_h * 0.02):
            fotolar.append((x, y, w, h))
            
    if not fotolar:
        # Fotoğraf bulunamazsa tüm A4'ü tara
        print(f"0 0 {A4_W_MM} {A4_H_MM}")
        with open(json_yolu, 'w') as f:
            json.dump([{"ad": "tam_sayfa", "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0}], f)
        return

    # Tüm fotoğrafları içine alan en dış çerçeveyi (Bounding Box) bul
    min_x = min([f[0] for f in fotolar])
    min_y = min([f[1] for f in fotolar])
    max_x = max([f[0]+f[2] for f in fotolar])
    max_y = max([f[1]+f[3] for f in fotolar])
    
    # Kenarlardan 3mm pay bırak (Kesilme olmasın diye)
    padding_x = int(img_w * (3.0 / A4_W_MM))
    padding_y = int(img_h * (3.0 / A4_H_MM))
    
    min_x = max(0, min_x - padding_x)
    min_y = max(0, min_y - padding_y)
    max_x = min(img_w, max_x + padding_x)
    max_y = min(img_h, max_y + padding_y)
    
    global_w = max_x - min_x
    global_h = max_y - min_y
    
    # JSON için asıl taranacak alana göre bağıl (relative) koordinatları hesapla
    json_data = []
    for i, (x, y, w, h) in enumerate(fotolar):
        rel_x = (x - min_x) / global_w
        rel_y = (y - min_y) / global_h
        rel_w = w / global_w
        rel_h = h / global_h
        json_data.append({
            "ad": f"foto_{i+1}",
            "x": round(rel_x, 4),
            "y": round(rel_y, 4),
            "w": round(rel_w, 4),
            "h": round(rel_h, 4)
        })
        
    with open(json_yolu, 'w') as f:
        json.dump(json_data, f)
        
    # scanimage komutu için mm cinsinden koordinatları bash'e gönder
    mm_l = (min_x / img_w) * A4_W_MM
    mm_t = (min_y / img_h) * A4_H_MM
    mm_w = (global_w / img_w) * A4_W_MM
    mm_h = (global_h / img_h) * A4_H_MM
    
    print(f"{mm_l:.1f} {mm_t:.1f} {mm_w:.1f} {mm_h:.1f}")

if __name__ == "__main__":
    bul(sys.argv[1], sys.argv[2])