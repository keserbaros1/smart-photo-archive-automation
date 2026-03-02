import cv2
import sys
import os
import urllib.request
from PIL import Image

# Model dosyaları (Betik ile aynı klasöre indirilecek)
MODEL_DIR = os.path.dirname(os.path.abspath(__file__))
PROTOTXT = os.path.join(MODEL_DIR, "deploy.prototxt")
MODEL = os.path.join(MODEL_DIR, "res10_300x300_ssd_iter_140000.caffemodel")

def modelleri_indir():
    if not os.path.exists(PROTOTXT):
        print("   ⬇️ Yüz tanıma yapay zeka modeli indiriliyor (Prototxt)...")
        urllib.request.urlretrieve("https://raw.githubusercontent.com/opencv/opencv/master/samples/dnn/face_detector/deploy.prototxt", PROTOTXT)
    if not os.path.exists(MODEL):
        print("   ⬇️ Yüz tanıma yapay zeka modeli indiriliyor (Caffemodel)...")
        urllib.request.urlretrieve("https://raw.githubusercontent.com/opencv/opencv_3rdparty/dnn_samples_face_detector_20170830/res10_300x300_ssd_iter_140000.caffemodel", MODEL)

def yuzu_bul_ve_dondur(resim_yolu):
    modelleri_indir()
    
    # DNN Modelini Yükle
    net = cv2.dnn.readNetFromCaffe(PROTOTXT, MODEL)
    
    cv_img = cv2.imread(resim_yolu)
    if cv_img is None: return

    yonler = [
        (0, None), 
        (270, cv2.ROTATE_90_CLOCKWISE), 
        (180, cv2.ROTATE_180), 
        (90, cv2.ROTATE_90_COUNTERCLOCKWISE)
    ]

    en_iyi_aci = 0
    en_yuksek_guven = 0.0

    for aci, donusum in yonler:
        test_img = cv_img
        if donusum is not None:
            test_img = cv2.rotate(cv_img, donusum)
        
        # Resmi modele uygun hale getir
        blob = cv2.dnn.blobFromImage(cv2.resize(test_img, (300, 300)), 1.0, (300, 300), (104.0, 177.0, 123.0))
        net.setInput(blob)
        detections = net.forward()
        
        # Bulunan yüzlerin güvenilirlik oranına bak
        for i in range(detections.shape[2]):
            guven = detections[0, 0, i, 2]
            if guven > 0.6: # %60'dan fazla eminse yüz kabul et
                if guven > en_yuksek_guven:
                    en_yuksek_guven = guven
                    en_iyi_aci = aci

    if en_iyi_aci != 0 and en_yuksek_guven > 0.6:
        print(f"   🔄 Yüz bulundu (%{int(en_yuksek_guven*100)} emin)! {en_iyi_aci} derece döndürülüyor: {os.path.basename(resim_yolu)}")
        pil_img = Image.open(resim_yolu)
        icc = pil_img.info.get('icc_profile')
        pil_img = pil_img.rotate(en_iyi_aci, expand=True)
        pil_img.save(resim_yolu, 'PNG', icc_profile=icc)

if __name__ == "__main__":
    if len(sys.argv) == 2:
        yuzu_bul_ve_dondur(sys.argv[1])
