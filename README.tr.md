🇬🇧 [Read in English](README.md)

# 📸 Akıllı Fotoğraf Tarama ve İşleme Otomasyonu (Smart Photo Scanner)

Bu proje, basılı eski fotoğraflarınızı en yüksek kalitede SANE (`scanimage`) ile yüksek çözünürlükte (RAW TIFF) taramak, **Yapay Zeka destekli otomatik kesme**, **yüz analizi ile otomatik döndürme**, ve yeni nesil formatlarda (AVIF/HEIC) kayıpsız olarak sıkıştırmak için tasarlanmış uçtan uca bir otomasyon sistemidir. 

Ayrıca tam entegre bir **Home Assistant** arayüzü ile fiziksel bir bilgisayar başına geçmeden tüm tarama süreçlerini doğrudan cep telefonunuz üzerinden yönetebilirsiniz.

---

## 🚀 Gelişmiş Özellikler

- **🤖 Otomatik Sınır Algılama (Auto-Crop):** Tarayıcı önce tüm camı çok hızlı (75 DPI) ve düşük çözünürlükte tarar. Python (OpenCV) camdaki fotoğrafların yerini milimetrik olarak tespit eder ve **sadece fotoğrafların olduğu o alt bölgeleri** yüksek çözünürlükte (örn: 1200 DPI) tarayarak devasa zaman ve gereksiz HDD boşa yazım tasarrufu sağlar.
- **✂️ Dinamik Kesim (JSON Destekli):** Ayrı ayrı tespit edilen fotoğrafların koordinatları `.json` dosyasına şablon olarak yazılır. İşleme aşamasında devasa boyutlu asıl TIFF taraması bu koordinatlara göre, orijinal ICC renk profilleri ve DPI meta verisi %100 noktası noktasına korunarak parçalara ayrılır (Pillow kullanılarak).
- **🔄 Yapay Zeka ile Yüz Yönü Bulma:** Ters veya yan taranmış fotoğraflar, *OpenCV Deep Neural Network (DNN) Caffe Modeli* (`res10_300...caffemodel`) sayesinde, içerisindeki yüzler yüksek keskinlikle analiz edilerek otomatik biçimde dikey boyuta döndürülür (~%60+ güvenilirlik seviyesi hesaplanarak).
- **📦 Kayıpsız YeniNesil Sıkıştırma:** Fotoğraflarınız donanım kısıtlamalarını ve ekran kartı hatalarını (NVENC vs) aşarak maksimum arşiv kalitesi sunabilmesi için salt CPU tabanlı `avifenc` (AOM) veya `heif-enc` sıkıştırma işlemleriyle en verimli formatlara (AVIF / HEIC) dönüştürülür. Lossless (Kayıpsız) / Lossy (Kayıplı) ve özel sıkıştırma kodlama hızı seçenekleri ile özelleştirilebilir.
- **🌐 Ağ (SMB/CIFS) Desteği:** İşlenecek dosyaları yerel Linux diski yerine ağınızdaki bir NAS cihazında veya paylaşım sunucusunda barındırıp doğrudan oradan çalıştırabilirsiniz. Betik, ağ sürücülerini otomatik "mount" bağlar ve işlem bittiğinde "unmount" ederek güvenle ayrılır.

---

## 📂 Dosya Yapısı ve Görevleri

* `scan.sh`: Tarayıcınızı yöneten ana tetikleyici kabuk betiğidir. "Otomatik (Önizleme+Algılama)" veya "Özel Ölçü" (Örn: X/Genişlik:100 Y/Yükseklik:150 mm) modlarında çalışır.
* `otomatik_sinir_bul.py`: `scan.sh` tarafından o anki hızlı önizleme dosyasını analiz etmek için arka planda çağrılır, asıl yüksek çözünürlük ile taranacak mm sınırlarını hesaplar ve parçalama .json kesim şablonunu oluşturur.
* `isle_fotolari.sh`: Ham `tıff/json` blok dosyalarını topluca bulur, Python betik dizisini sırayla çalıştırır, alt klasöleri/çöp klasörleri oluşturur ve belirlediğiniz parametrelerde yüksek sıkıştırmayı yapar.
* `sabit_kirp.py`: Ham TIFF dosyalarını hiçbir renk modülünü veya DPI miktarını bozmadan okur ve `.json` değerlerine bölümlerine göre ayırarak ana çıktıyı klasöre geçirir.
* `yuz_dondur.py`: Parçalanmış ve oluşturulmuş son TIFF çıktılarındaki yüzleri AI/DNN Caffe ile tespit edip resmi hatasız izometrik bir şekliyle dikey açıya döndürür. (*Çevrimdışı çalışabilmek için gereken Caffe yapay zeka model dosyalarını ilk seferinde otomatik olarak internetten kurar*).

---

## 🛠️ Kurulum ve Sistem Gereksinimleri

Proje Debian/Ubuntu tabanlı sistemlerde (Native Linux cihazlar veya WSL yapıları) sorunsuz çalışmak üzere tasarlanmıştır. 
Kurucu betik olan (`isle_fotolari.sh`) ilk defa çalıştırıldığında gerekli olan ana bağımlılıkları kontrol der ve eksikleri otomatik olarak APT üstünden kurar. 

Farklı konfigürasyonlarda manuel kurmak isterseniz:
```bash
sudo apt-get update
sudo apt-get install cifs-utils libavif-bin libheif-examples python3-opencv python3-pil
```
*(Not: AI Yüz tanıma için gereken `.prototxt` ve `.caffemodel` uzantılı makine eğitim ağırlığı dosyaları sadece sisteme ihtiyaç duyulduğu safhada `yuz_dondur.py` modülü tarafından otomatik indirilip kullanılır.)*

---

## 💻 Sistem Kullanımı

### 1. Sisteme Fotoğraf Taratmak (`scan.sh`)
Tarayıcınızın bağlı olduğu ana Linux terminalinde doğrudan şu tetikleyiciyi başlatın:
```bash
bash scan.sh
```
Açılan menüde "**Otomatik**" seçeneğini belirlediğinizde, tarayıcı camına yan yana rastgele yerleştirdiğiniz bütün fotoğrafların konum sınırları yapay zeka ile tespit edilir, sadece o tespitli spesifik odaklar yüksek çözünürlükte taranır (Zaman kazanır) ve yanlarında o koordinatları barındıran tam uyumlu bir `.json` modülü dosyası ile ham çıktılar klasörüne `scan_X...` ön adıyla kaydedilir. 
Menüden doğrudan özel milimetre boyutları seçerek kendi çizdiğiniz alanınız dahilinde sabit taranmasını sağlayabilirsiniz.

### 2. Taranmış Fotoğrafları Veri Olarak İşletmek (`isle_fotolari.sh`)
Uzak klasörde yansıyan tüm ham `.tiff` ve `.json` ekili dosya kuyruğunu son kullanıcı bitmiş formatlarına (AI kesim, Caffe Yüz Döndürme vb.) çevirmek için betiği terminalde bir defa `sudo` yetkisiyle çağırın (*çıktı dosyalarının sistem izinleri sudo aşamasında kilitlenmeyecektir işlem yapan o kısımdaki doğal hesabınıza ait olacaktır*):
```bash
sudo bash isle_fotolari.sh
```
Betik konsolu size interaktif adımlar halinde soracaktır: (Yerel ya da Ağ Dosyası yolu, tarih maskelemesi / seçimi, AVIF mi HEIC mi / Lossless / Sıkıştırma Motor Hızı) gibi filtrelerden geçer atamasını kendi üzerine kitler ve tam otomatik arka plan sürecinde fotoğrafları son haline getirir.

---

## 🏡 Akıllı Ev: Home Assistant Entegrasyonu

Tarayıcınızı dışa açarak Home Assistant üzerinden tam teşekküllü (Profil seçimi, DPI ölçeklendirmesi ve Özel Milimetrik X/Y değerlerini) yönetebilmek ve doğrudan uzaktan taramayı bir düğmeyle ev ağı içindeki her mecradan kontrol etmek için:

1. **Özel SSH Köprü Anahtarı:** Home Assistant'ın terminalinin sunucunuza sorunsuz/şifresiz iletişim geçiş paneli yapabilmesi için bir kimlik RSA anahtarı oluşturup yetkilendirin:
   ```bash
   # Home Assistant terminalinde çalıştırılacak kimlik komutu:
   ssh-keygen -t rsa -b 4096 -f /config/ssh_key
   ssh-copy-id -i /config/ssh_key kullanici_adi@sunucu_adresi
   ```
2. **HA Konfigürasyon Dosyasına Geçiş (`configuration.yaml`):** Proje içeriğindeki `ha_configuration_example.yaml` taslağındaki şablon verisini Home Assistant'ınızın kendi `configuration.yaml` dosyasına yapıştırın. *(Shell/Sensor komutlarındaki kendi IP veya kullanıcı adı verinizi değiştirin)*
3. **Lovelace Kartı (UI):** Home Assistant panonuzda yeni bir "Manuel (Manual)" Dashboard Kartı ekleyip projedeki `ha_lovelace_card.yaml` verisini doğrudan ona giydirin.

Hayırlı olsun, bir fiziksel monitöre ve terminal yığınına gitmeksizin evinizin içerisindeki tüm cihazlarınız ile son derece güvenli şekilde tarama operasyonu kurabilirsiniz!

---

## 💡 Pratik İpuçları (Manuel Kesim Gerektiren Ağır İstisnai Durumlar)

Basılı nesne yapay zeka sınırlarının çok silik olduğu (Tamamı solmuş/beyaz çıkmış arayüzeyler, çok aşırı yırtık kavisli nostaljik 1800'lerden kalma resimler) gibi AI sınır bulmasının şaştığı spesifik zor kısımlar manuel kurtarılmalıdır, ancak web tabanlı basit editörler (Photopea vb.) kesinlikle **KULLANILMAMALIDIR!** Bu uygulamalar projeyle kazandığınız 1200 DPI kalite / profesyonel `icc_profile` kalibrasyonunu çöpe atıp sıradan ekran resim formatına sıkıştırıp renk/boyut kalitesini ezerler.

Windows üzerinden asıl renk/DPI datasını gram bozmadan orijinal `.tiff` dosyalarından parçalı kesim almanın en hatasız ve emniyetli yolu **IrfanView** masaüstü uygulamasını kullanmaktır:

1. Ana dizinindeki devasa çözünürlüğe sahip asıl `*.tiff` orijinal resmini IrfanView ile içeriye alın.
2. Kesilmesi gereken ana hedefin dış yüzeyinden farenin sol tuşunu kullanarak seçili bir çizgi kutuyu kement gibi yaratın (Seçimi oransal oynamak isterseniz **Shift + C** (Custom Selection) yapabilirsiniz.)
3. Hemen **Ctrl + Y** *(Crop Selection / Seçileni kırp çıkar)* kısayolunu kullanın. Resmi ufaltmış olur.
4. Çıktı için **S** tuşuyla "Farklı Kaydet" penceresine ulaşıp dosya alt tipinden uzantı listesini **TIFF** konumuna düzeltin.
5. Sağ taraftaki beliren kaydetme yardımcı menüsündeki `"Save ICC Profile"` ve `"Keep original EXIF data"` kısımlarını onaylayıp tikleyin. ZIP ve LZW sıkıştırma sekmesinin (kayıpsızdır) işaretli olduğuna da özen gösterin.
6. Seçili parçayı ayrı TIFF dosyası gibi diske bağımsız dışa yazdırın.
7. Diğer eski nesneleri kesme adımına geçmek için **Ctrl + Z** tuşlarına basarak ana resme orijinal konuma dönün ve sıradakini kesin.

*(Cihaz bu sizin el yordamıyla böldüğünüz/ayıklattığınız tiff dosyası kısımlarını aynı şekilde anlayıp \`isle_fotolari.sh\` süreç panelinden kalite, düz rotasyon vb filtrelerle çalıştırıp olağan son AVIF/HEIC format çıktılarını vermeye otomatize biçimde devam edecektir.)*
