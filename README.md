# PeakLayout

Menü çubuğunda çalışan macOS uygulaması. Masaüstü ikonlarını, harici monitör değişse bile sabit bir
düzende tutar:

```
… [D5] [D1]  │  Klasör 1
  [D6] [D2]  │  Klasör 2
  [D7] [D3]  │  Klasör 3
  [D8] [D4]  │  …
```

- **Sağ sütun:** seçtiğin sabit öğeler (klasör, disk…), ayarlardaki sırayla. Elle kaydırılırsa
  20 sn içinde geri konur.
- **Bir boş sütun**, sonra diğer dosyalar yukarıdan aşağı, sütun dolunca sola.
- **Sona ekleme:** yeni dosya sıradaki slota gider, mevcutlar oynamaz. Silinenlerin boşluğu
  menüdeki *Boşlukları kapat* ile kapanır. Kimlik inode'dur; yeniden adlandırmak yeri değiştirmez.
- **Downloads:** uygulama ilk açıldıktan sonra `~/Downloads`'a inen dosyalar, indirme bitince
  (boyut 2 sn sabit, `.crdownload` vb. değil) masaüstüne taşınır. Ayarlardan kapatılabilir.
- **Monitör:** ana ekran değişince (ör. kapak kapalı harici monitör) 3 ve 8 sn sonra yerleşim yeniden
  uygulanır. Koordinatlar sağ kenara göre hesaplandığı için farklı genişlikteki monitörlerde de sabit
  sütun aynı görünür.

## Nasıl çalışır

| Dosya | Görev |
|---|---|
| `LayoutEngine.swift` | Ekran boyutu + ölçülerden hücre koordinatları, slot ataması |
| `FinderBridge.swift` | AppleScript ile `desktop position` okuma/yazma (tek betikte toplu) |
| `DesktopScanner.swift` | Finder adlarını dosya sistemiyle eşler, gizli/Office artıklarını eler |
| `DirectoryWatcher.swift` | `~/Desktop` ve `~/Downloads` değişikliklerini izler |
| `DownloadsMover.swift` | Bitmiş indirmeleri masaüstüne taşır |
| `DisplayMonitor.swift` | Ekran değişimi / uykudan uyanma |
| `AppModel.swift` | Hepsini birleştirir; her yerleşimden önce yedek alır |

Finder koordinatları ana ekranın sol üstünden, point cinsindendir. Varsayılan ölçüler 88 pt ikon
boyutu ve 14 pt yazı içindir (sağ boşluk 160, ilk satır 83, sütun 108, satır 126). Sabit öğeleri
Finder'da doğru yere koyup ayarlardan **Şu anki konumlardan ölç** ile kendi ekranına kalibre et.

## Kurulum

Gereksinim: macOS 14+, Xcode. `PeakLayout.xcodeproj` içindeki `DEVELOPMENT_TEAM` değerini kendi Apple
geliştirici takımınla değiştir (Xcode › Signing & Capabilities).

```bash
xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/PeakLayout.app /Applications/
open /Applications/PeakLayout.app
```

İlk açılışta Finder'ı denetleme ve Masaüstü/Downloads erişim izinleri istenir, *Oturum açılınca
başlat* kendiliğinden açılır. Menü ikonu › **Ayarlar…** › sağ sütuna masaüstünden öğe ekle.

## Logolar

İkonlar kodla çizilir (CoreGraphics): ızgara karelerinden oluşan karlı zirve, bir boş sütun ve sabit
sütun.

```bash
# Uygulama ikonu
A=PeakLayout/Assets.xcassets/AppIcon.appiconset
swift scripts/render-icon.swift $A/icon_1024.png
for s in 16 32 64 128 256 512; do sips -z $s $s $A/icon_1024.png --out $A/icon_$s.png; done

# Menü çubuğu şablon ikonu (18 pt, 1x/2x/3x)
swift scripts/render-menubar-icon.swift PeakLayout/Assets.xcassets/MenuBarIcon.imageset
```

## Yedekler

`~/Library/Application Support/PeakLayout/Backups/` — her yerleşimden önceki konumlar (son 20).
Menüdeki *Son yedeğe geri dön* otomatik düzeni duraklatıp eski konumları geri yükler.

## Lisans

[MIT](LICENSE) © 2026 Peakode
