# PeakLayout

[English](README.md) · **Türkçe**

Masaüstü ikonlarını, harici monitörler arasında geçiş yapsan bile sabit bir düzende tutan macOS menü
çubuğu uygulaması.

```
… [D5] [D1]  │  Klasör 1
  [D6] [D2]  │  Klasör 2
  [D7] [D3]  │  Klasör 3
  [D8] [D4]  │  …
```

## Neden?

macOS, ana ekran her değiştiğinde masaüstü ikonlarını yeniden dizer. MacBook'u 49" geniş monitöre
bağlayıp kapağı kapattığında özenle yerleştirdiğin klasörler dağılır; çıkardığında aynısı tekrar olur.
Yeni indirilen dosyalar da Finder boş yer nerede bulursa oraya düşer. PeakLayout her şeyi otomatik
olarak ait olduğu yere geri koyar.

## Kullanım senaryoları

**1. Masada, kapak kapalı çalışan dizüstü.**
Gün içinde MacBook ile çalışıyorsun, masana geçince kapağı kapatıp Samsung 49" monitöre bağlıyorsun.
Monitör algılandığı anda PeakLayout, Finder'ın kendi dizmesini bitirmesini bekler ve düzenini geri
getirir: ana klasörlerin sağ sütunda, her zamanki sırasıyla.

**2. İki masa, iki monitör.**
Evde 27", ofiste 49". Konumlar ekranın sağ kenarına göre hesaplandığı için sabit sütunun ikisinde de
aynı görünür; geniş ekranda sadece dosyalara daha çok yer kalır.

**3. Kaybolmayan indirmeler.**
İnmesi biten her dosya `~/Downloads`'tan masaüstüne taşınır ve sıradaki boş yere konur. Mevcut dosyalar
yerinden oynamaz, en yeni dosya her zaman en sondadır.

**4. Yanlışlıkla kaydırma ve "Düzenle".**
Bir klasörü kaydırdın ya da Finder masaüstünü yeniden sıraladı. Sabit klasörler 20 saniye içinde yerine
döner. Her yerleşimden önce eski konumlar yedeklenir, tek tıkla geri alabilirsin.

## Yerleşim nasıl çalışır

- **Sağ sütun:** Ayarlar'da seçtiğin sabit öğeler (klasör, disk…), seçtiğin sırayla.
- **Bir boş sütun** ayraç olarak.
- **Diğer her şey** yukarıdan aşağı dolar, sütun bitince bir sola geçer.
- **Sona ekleme:** yeni dosya sıradaki yere gider, mevcutlar oynamaz. Silinenlerin boşluğu *Boşlukları
  kapat* seçilene kadar kalır. Dosyalar inode ile izlenir; yeniden adlandırmak yerini değiştirmez.
- **İndirmeler** ancak bitince taşınır (boyut 2 sn sabit, `.crdownload` vb. değil) ve sadece uygulama ilk
  açıldıktan sonra gelen dosyalar için. Kapatılabilir.
- **Ekran değişimi** (ve uykudan uyanma) sonrasında yerleşim 3 ve 8 saniye sonra yeniden uygulanır.

## Dil

Uygulama **İngilizce** ve **Türkçe** olarak kullanılabilir ve macOS dilini izler. Sadece PeakLayout için
dil seçmek istersen: *Sistem Ayarları › Genel › Dil ve Bölge › Uygulamalar › +*.

## Kurulum

Gereksinim: macOS 14+, Xcode. `PeakLayout.xcodeproj` içindeki `DEVELOPMENT_TEAM` değerini kendi Apple
geliştirici takımınla değiştir (Xcode › Signing & Capabilities).

```bash
xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/PeakLayout.app /Applications/
open /Applications/PeakLayout.app
```

İlk açılışta macOS, Finder'ı denetleme ve Masaüstü/Downloads erişimi için izin ister. *Oturum açılınca
başlat* kendiliğinden açılır. Sonra menü çubuğu ikonu › **Ayarlar…** yolundan masaüstündeki sabit
öğelerini ekle. Finder ikon boyutun varsayılandan farklıysa sabit öğeleri istediğin yere koyup **Şu anki
konumlardan ölç**'e bas.

## Mimari

| Dosya | Görev |
|---|---|
| `LayoutEngine.swift` | Ekran boyutu ve ölçülerden hücre koordinatları, slot ataması |
| `FinderBridge.swift` | AppleScript ile `desktop position` okuma/yazma (tek betikte toplu) |
| `DesktopScanner.swift` | Finder adlarını dosya sistemiyle eşler, gizli/Office artıklarını eler |
| `DirectoryWatcher.swift` | `~/Desktop` ve `~/Downloads` klasörlerini izler |
| `DownloadsMover.swift` | Bitmiş indirmeleri masaüstüne taşır |
| `DisplayMonitor.swift` | Ekran değişimi ve uykudan uyanma |
| `AppModel.swift` | Hepsini birleştirir; her yerleşimden önce konumları yedekler |

Finder koordinatları ana ekranın sol üstünden, point cinsindendir. Varsayılan ölçüler 88 pt ikon boyutu
ve 14 pt yazı içindir (sağ boşluk 160, ilk satır 83, sütun 108, satır 126). Arayüz metinleri
`Localizable.xcstrings`, izin pencereleri `InfoPlist.xcstrings` dosyasındadır.

## Yedekler

`~/Library/Application Support/PeakLayout/Backups/` her yerleşimden önceki konumları tutar (son 20).
Ayarlar'daki *Son yedeğe geri dön* otomatik düzeni duraklatıp bunları geri yükler.

## İkonlar

İki ikon da CoreGraphics ile kodla çizilir: ızgara karelerinden oluşan karlı zirve, bir boş sütun ve
sabit sütun.

```bash
# Uygulama ikonu
A=PeakLayout/Assets.xcassets/AppIcon.appiconset
swift scripts/render-icon.swift $A/icon_1024.png
for s in 16 32 64 128 256 512; do sips -z $s $s $A/icon_1024.png --out $A/icon_$s.png; done

# Menü çubuğu şablon ikonu (18 pt, 1x/2x/3x)
swift scripts/render-menubar-icon.swift PeakLayout/Assets.xcassets/MenuBarIcon.imageset
```

## Lisans

[MIT](LICENSE) © 2026 Peakode
