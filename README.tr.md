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

**4. Tek ekran, üç çalışma alanı.**
49" geniş monitörde üç ayrı monitör varmış gibi çalışırsın: solda sohbet, ortada tarayıcı, sağda posta.
Bu uygulamaları açtığında her pencere kendi sütununa kendiliğinden gider; yeniden başlatmadan sonra da,
monitörü çıkarıp taktıktan sonra da.

**5. Yanlışlıkla kaydırma ve "Düzenle".**
Bir klasörü kaydırdın ya da Finder masaüstünü yeniden sıraladı. Sabit klasörler 20 saniye içinde yerine
döner. Her yerleşimden önce eski konumlar yedeklenir, tek tıkla geri alabilirsin.

## Pencere bölgeleri

PeakLayout ekranı dikey bölgelere de böler ve her uygulamayı kendi bölgesine yollar. 49" geniş
monitörde bu üç eşit sütun demek: solda sohbet, ortada tarayıcı, sağda posta. Her sabah elle
sürüklemek yerine kendiliğinden yerine gelir.

- **Bölgeler:** 2–4 sütun, varsayılan olarak eşit; genişlikleri değiştirilebilir, araya boşluk
  konabilir. Menü çubuğu ve Dock hariç tutulur, pencereler tam oturur.
- **Kurallar:** uygulama başına bir bölge, uygulama kimliğiyle eşleşir. Kuralı olmayan uygulamalara
  dokunulmaz.
- **Ne zaman uygulanır:** kurallı uygulama açıldığında, ekran değiştiğinde, PeakLayout başladığında ve
  menüdeki *Pencereleri düzenle* ile.
- **Atlananlar:** küçültülmüş ve tam ekran pencereler, bir de boyut değiştirmeyi kabul etmeyen
  pencereler (bazı uygulamaların pencere boyutu sabittir). Bunlar zorlanmaz, bildirilir.

*Ayarlar › Pencereler*'den açılır. Erişilebilirlik izni gerekir, aşağıda anlatılıyor.

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

macOS 14 veya üstü gerekir. Apple silicon ve Intel Mac'lerde çalışır. Xcode gerekmez.

1. [Releases](https://github.com/peakode/PeakLayout/releases/latest) sayfasından **PeakLayout-x.y.dmg** dosyasını indir.
2. DMG'yi aç ve **PeakLayout**'u **Applications** klasörüne sürükle.
3. PeakLayout'u Uygulamalar'dan başlat. Uygulama Developer ID ile imzalı ve Apple tarafından onaylı
   (notarized) olduğu için macOS sadece alışılmış *"internetten indirildi"* onayını sorar — **Aç**'a bas.
4. İzin pencerelerini onayla (bkz. [İzinler](#izinler)).
5. Menü çubuğu ikonu › **Ayarlar…** yolundan masaüstündeki sabit öğelerini ekle. Finder ikon boyutun
   varsayılandan farklıysa sabit öğeleri istediğin yere koyup **Şu anki konumlardan ölç**'e bas.

Kaldırmak için: menü çubuğu ikonu › **Çıkış**, sonra PeakLayout'u Uygulamalar'dan Çöp Sepeti'ne taşı.

<a name="izinler"></a>
## İzinler

PeakLayout tamamen senin Mac'inde çalışır. İnternete bağlanmaz, veri toplamaz; Erişilebilirlik, Ekran
Kaydı ya da Tam Disk Erişimi istemez.

| İzin | macOS nerede sorar | PeakLayout neden ister |
|---|---|---|
| **Otomasyon › Finder** | *"PeakLayout", "Finder"ı denetlemek istiyor* | Masaüstü ikonlarının konumları Finder'a aittir. PeakLayout her ikonun konumunu Finder'ın AppleScript arayüzüyle okur ve taşır. Bu izin olmadan hiçbir şey yerleştirilemez. |
| **Masaüstü klasörü** | *"PeakLayout" Masaüstü klasörünüzdeki dosyalara erişmek istiyor* | Dosya eklendiğini, adı değiştiğini ya da silindiğini fark edip yeni öğeyi sıradaki boş yere koymak için. Sadece dosya adları ve tarihleri okunur, dosyaların içeriği açılmaz. |
| **Downloads klasörü** | *"PeakLayout" İndirilenler klasörünüzdeki dosyalara erişmek istiyor* | İnmesi biten dosyaları masaüstüne taşımak için. Sadece *Downloads'a gelenleri masaüstüne taşı* açıksa istenir; kapatınca Downloads'a hiç erişilmez. |
| **Erişilebilirlik** | *"PeakLayout" bilgisayarı erişilebilirlik özellikleriyle denetlemek istiyor* | Sadece pencere bölgeleri için. macOS pencere konum ve boyutunu Erişilebilirlik API'siyle açar; pencere taşıyan her uygulamanın tek yolu budur. PeakLayout sadece kural yazdığın uygulamaların pencere konum ve boyutunu okur ve yazar, başka bir şey yapmaz. Pencere bölgeleri kapalıysa hiç istenmez. |
| **Oturum açma öğesi** | Bildirim: *"PeakLayout" bir oturum açma öğesi ekledi* | Bilgisayar yeniden başladığında uygulamayı elle açmadan düzenin geri gelmesi için. Ayarlar'dan ya da *Sistem Ayarları › Genel › Oturum Açma Öğeleri*'nden kapatılabilir. |

Uygulama sandbox'lı değildir, çünkü sandbox içindeki bir uygulama Finder'a Apple Event gönderemez. Bu
izinlerin hepsini *Sistem Ayarları › Gizlilik ve Güvenlik* (Otomasyon, Dosyalar ve Klasörler) ve
*Genel › Oturum Açma Öğeleri* altından görebilir ya da geri alabilirsin.

## Kaynaktan derleme

Xcode gerekir. `PeakLayout.xcodeproj` içindeki `DEVELOPMENT_TEAM` değerini kendi Apple geliştirici
takımınla değiştir (Xcode › Signing & Capabilities), sonra:

```bash
xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/PeakLayout.app /Applications/
```

### Sürüm yayınlama

`scripts/release.sh`, universal uygulamayı ve sürükle-bırak DMG'yi `dist/` klasörüne üretir;
`scripts/release.sh --publish` ayrıca GitHub release'ini oluşturur. Anahtar zincirinde *Developer ID
Application* sertifikası ve bir notary profili
(`xcrun notarytool store-credentials PeakLayout-notary --apple-id … --team-id …`) varsa script uygulamayı
ve DMG'yi imzalayıp Apple'a onaylatır. Bunlar yoksa ad-hoc imzaya düşer ve kullanıcılar ilk açılışı
*Sistem Ayarları › Gizlilik ve Güvenlik › Yine de Aç* ile onaylamak zorunda kalır.

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
