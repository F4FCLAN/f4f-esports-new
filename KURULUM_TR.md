# F4F Esports — Kurulum Sırası

## Bu pakette neler var?
- `index.html`: F4F web arayüzü taslağı.
- `assets/f4f-red-silver-frame-background.jpeg`: Kullanıcının gönderdiği kırmızı/gümüş çerçeve arka planı; HTML içinde otomatik kullanılır. Ayrı yükleme gerekmez.
- `assets/f4f-logo-transparent.png`: Önceden onaylanan metalik kırmızı-siyah-gümüş F4F amblemi; üst logo, ana alan ve favicon için kullanılır.
- `supabase/player-profiles.sql`: Profil/veritabanı taslağı.
- `supabase/functions/admin-create-player/index.ts`: Yönetici tarafından hesap açma fonksiyonu taslağı.

## Güvenli kurulum sırası
1. GitHub deposundaki mevcut dosyaların yedeğini alın.
2. Supabase SQL Editor'de mevcut tablo şemasını kontrol edin.
3. **Mevcut tabloları kontrol etmeden `player-profiles.sql` dosyasını çalıştırmayın.** Önce `players`, `player_profiles`, `matches`, `match_requests`, `join_applications` sütunlarını inceleyip SQL'i mevcut yapıyla uyumlu hale getirin.
4. Bu taslağın giriş akışı e-posta tabanlıdır; kullanıcı adı + şifre ve sadece yöneticinin hesap açması isteniyorsa, bu özellik düzeltilmeden canlıya koymayın.
5. Yayına almadan önce RLS ile oyuncuların yalnızca kendi profilini değiştirebildiğini test edin. Gizli anahtarları HTML/JavaScript içine koymayın.
6. Son onaydan sonra `index.html` ve `assets/` klasörünü birlikte GitHub deposunun köküne yükleyin.

## Tasarım notu
Gönderdiğiniz çerçeve resmi paket içindedir. Site arka planında düşük opaklık ve koyu katmanla kullanılır; yazıların okunaklılığı korunur. Logoda önceki konuşmada onaylanan metalik F4F amblemi kullanılır.
