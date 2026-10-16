# F4F Esports — Kurulum ve yayına alma

Bu paket, GitHub Pages statik sitesi ve mevcut Supabase projesi için hazırlanmıştır. Logo ve kırmızı/gümüş arka plan `assets/` klasöründedir.

## Pakette neler var?
- `index.html`: mobil/masaüstü site; ana sayfa, Hakkımızda, oyuncu kadrosu ve profilleri, maç geçmişi, maç talebi, klan başvurusu, takip kodu, oyuncu girişi, yönetici paneli, tema ve gizlilik/çerez alanları.
- `assets/`: F4F logosu ve arka plan görseli.
- `supabase/setup.sql`: tablolar, RLS politikaları, takip kodu ve herkese açık güvenli profil RPC'leri, avatar bucket.
- `supabase/functions/admin-create-player/index.ts`: yönetici oturumuyla kullanıcı adı/şifre oyuncu hesabı oluşturan Edge Function.

## 1) Supabase veritabanı
1. Şu sayfayı aç: https://supabase.com/dashboard/project/tzlitqojgggrdsrpeycq/sql/new
2. `supabase/setup.sql` dosyasının tamamını SQL Editor'e yapıştır ve **Run** ile çalıştır.
3. Çalıştırma hatası görünürse hata metnini incele; başarılı çalıştığını doğrulamadan sonraki adıma geçme.

SQL, bu siteye ait beş tablodaki önceki prototip RLS politikalarını temizleyip bu paket için politikaları kurar. Çalıştırmadan önce mevcut veritabanının yedeğini almak iyi uygulamadır.

## 2) Yönetici rolünü doğrula
Supabase Dashboard → Authentication → Users bölümünde yönetici hesabını aç. **App Metadata** içinde `role: admin` bulunduğunu doğrula. Bu değer yoksa kullanıcıya ait App Metadata'ya `{"role":"admin"}` ekle. Bunu User Metadata'ya değil, App Metadata'ya ekle.

## 3) Oyuncu hesabı Edge Function'ı
1. Supabase Dashboard → Edge Functions bölümünde `admin-create-player` adında bir function oluştur.
2. `supabase/functions/admin-create-player/index.ts` dosyasının içeriğini function editörüne yapıştırıp deploy et.
3. Function, çağıranın Supabase oturumunu doğrular ve sadece App Metadata rolü `admin` olan kullanıcıya hesap oluşturtur. Service-role anahtarı HTML dosyasına eklenmemelidir.

Oyuncular kullanıcı adı ve şifreyle giriş yapar. Teknik olarak Supabase Auth altında dahili `@players.f4f.local` e-posta biçimi kullanılır; oyuncuların gerçek e-posta adresini siteye girmesi gerekmez.

## 4) GitHub Pages'e yükleme
1. ZIP'i bilgisayarında bir klasöre çıkar.
2. `index.html`, `assets` ve `supabase` öğelerini `https://github.com/F4FCLAN/f4f-esports-new` deposunun **kök dizinine** yükle. `index.html` bir alt klasörde kalmamalı.
3. GitHub → Settings → Pages bölümünde **Deploy from a branch**, `main`, `/(root)` seçili olsun.
4. Actions sekmesinde son Pages dağıtımının yeşil tik aldığını doğrula. Site: https://f4fclan.github.io/f4f-esports-new/

## 5) İlk test kontrol listesi
- Site açılışı, logo ve arka plan.
- Telefon ve bilgisayarda menü ve tema düğmesi.
- Test klan başvurusu gönderme ve takip kodunu sorgulama.
- Test maç talebi gönderme; yönetici panelinden onaylama ve sayaçta görünmesi.
- Yönetici panelinden oyuncu ekleme ve kullanıcı adı/şifre oluşturma.
- Oyuncu girişi, kendi profilini/TikTok bağlantısını düzenleme ve başka oyuncunun profilini değiştiremediğini doğrulama.
- Yönetici panelinden maç sonucu ekleme ve tüm cihazlarda maç geçmişinde görünmesi.

## Önemli notlar
- Site, veritabanı ve Edge Function kurulumu yapılmadan yalnızca HTML olarak açılırsa veritabanı özellikleri çalışmaz.
- `SUPABASE_PUBLISHABLE_KEY` tarayıcıda kullanılabilen publishable anahtardır; service-role/secret anahtarını asla HTML veya GitHub deposuna koyma.
- KVKK metni genel bilgilendirme taslağıdır. Yayına almadan önce gerçek veri sorumlusu, iletişim ve saklama/silme süresi bilgilerini ekleyip hukuki uygunluğunu kontrol et.
- Konsol Valorant istatistikleri Riot API üzerinden otomatik çekilmiyor; oyuncu isterse alanlara manuel değer girebilir.
