import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: PomodoroApp()));
}

class PomodoroApp extends StatefulWidget {
  const PomodoroApp({super.key});
  @override
  State<PomodoroApp> createState() => _PomodoroAppState();
}

class _PomodoroAppState extends State<PomodoroApp> {
  bool uygulamaBasladiMi = false;

  @override
  Widget build(BuildContext context) {
    return uygulamaBasladiMi
        ? const OrmanPaneli()
        : GirisEkrani(onBasla: () => setState(() => uygulamaBasladiMi = true));
  }
}

class GirisEkrani extends StatelessWidget {
  final VoidCallback onBasla;
  const GirisEkrani({super.key, required this.onBasla});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF022C22), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/buyuk-agac.png', height: 200),
            const SizedBox(height: 20),
            const Text("MUHAMMED SAĞLAM",
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3)),
            const Text("Pomodoro Forest",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w200)),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Hedeflerine odaklan, zamanını yönet ve devasa bir orman inşa et.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: onBasla,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: const Text("ORMANA GİRİŞ YAP",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class DikilenAgac {
  final String resim;
  final String tarih;
  DikilenAgac(this.resim, this.tarih);
  Map<String, dynamic> toJson() => {'resim': resim, 'tarih': tarih};
  factory DikilenAgac.fromJson(Map<String, dynamic> json) =>
      DikilenAgac(json['resim'], json['tarih']);
}

class OrmanPaneli extends StatefulWidget {
  const OrmanPaneli({super.key});
  @override
  State<OrmanPaneli> createState() => _OrmanPaneliState();
}

class _OrmanPaneliState extends State<OrmanPaneli> {
  int kalanSaniye = 1500;
  int toplamSeansSuresi = 1500;
  Timer? zamanlayici;
  bool calisiyorMu = false;
  bool molaModu = false;
  bool sesAcikMi = true;
  List<DikilenAgac> ormanim = [];
  int bugunkuAgacSayisi = 0;
  String mevcutSoz = "Her fidan yeni bir başlangıçtır...";

  BannerAd? _bannerAd;
  bool _reklamYuklendiMi = false;

  final TextEditingController _calismaController =
      TextEditingController(text: "25");
  final TextEditingController _molaController =
      TextEditingController(text: "5");
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _fxPlayer = AudioPlayer();

  final List<String> motivasyonHavuzu = [
    "Fırtına ne kadar sert olursa olsun, ağaçlar köklerine güvenir.",
    "Büyük işler, küçük başlangıçlarla büyür.",
    "Bugün diktiğin fidan, yarınki gölgendir.",
    "Odaklanmak, başarının en güçlü tohumudur.",
    "Kendi ormanının mimarı sensin."
  ];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _reklamiHazirla();
  }

  void _reklamiHazirla() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _reklamYuklendiMi = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Reklam yüklenemedi: $error');
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ormanData = prefs.getString('orman_verisi');
    if (ormanData != null) {
      final List<dynamic> decodeData = jsonDecode(ormanData);
      setState(() {
        ormanim = decodeData.map((item) => DikilenAgac.fromJson(item)).toList();
        _gunlukSayacGuncelle();
      });
    }
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodeData =
        jsonEncode(ormanim.map((a) => a.toJson()).toList());
    await prefs.setString('orman_verisi', encodeData);
  }

  void _gunlukSayacGuncelle() {
    String bugun = DateTime.now().toString().split(' ')[0];
    setState(() =>
        bugunkuAgacSayisi = ormanim.where((a) => a.tarih == bugun).length);
  }

  String dinamikAgacGetir() {
    double ilerleme = 1 - (kalanSaniye / toplamSeansSuresi);
    if (molaModu) return 'assets/buyuk-agac.png';
    if (ilerleme < 0.25) return 'assets/fidan.png';
    if (ilerleme < 0.50) return 'assets/genc-agac.png';
    if (ilerleme < 0.75) return 'assets/cicekli-agac.png';
    return 'assets/buyuk-agac.png';
  }

  void baslatDurdur() {
    if (calisiyorMu) {
      zamanlayici?.cancel();
      _bgPlayer.stop();
      setState(() => calisiyorMu = false);
    } else {
      setState(() {
        calisiyorMu = true;
        toplamSeansSuresi = (molaModu
                ? int.parse(_molaController.text)
                : int.parse(_calismaController.text)) *
            60;
      });
      if (sesAcikMi) {
        _bgPlayer.setReleaseMode(ReleaseMode.loop);
        _bgPlayer.play(AssetSource('rain.mp3'), volume: 0.15);
      }
      zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && kalanSaniye > 0) {
          setState(() => kalanSaniye--);
        } else if (kalanSaniye == 0) {
          timer.cancel();
          _seansBitti();
        }
      });
    }
  }

  void sifirla() {
    zamanlayici?.cancel();
    _bgPlayer.stop();
    setState(() {
      calisiyorMu = false;
      molaModu = false;
      kalanSaniye = (int.tryParse(_calismaController.text) ?? 25) * 60;
    });
  }

  void _seansBitti() async {
    _bgPlayer.stop();
    if (sesAcikMi) await _fxPlayer.play(AssetSource('bip.mp3'));
    setState(() {
      calisiyorMu = false;
      if (!molaModu) {
        String bugun = DateTime.now().toString().split(' ')[0];
        ormanim.add(DikilenAgac('assets/buyuk-agac.png', bugun));
        _verileriKaydet();
        _gunlukSayacGuncelle();
        molaModu = true;
      } else {
        molaModu = false;
      }
      kalanSaniye = (molaModu
              ? int.parse(_molaController.text)
              : int.parse(_calismaController.text)) *
          60;
      mevcutSoz = motivasyonHavuzu[Random().nextInt(motivasyonHavuzu.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            molaModu ? const Color(0xFF065F46) : const Color(0xFF064E3B),
        elevation: 0,
        title: const Text("Pomodoro Forest",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.forest, color: Colors.greenAccent),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OrmanManzarasi())),
          ),
          IconButton(
            icon: Icon(sesAcikMi ? Icons.volume_up : Icons.volume_off,
                color: Colors.white70),
            onPressed: () {
              setState(() {
                sesAcikMi = !sesAcikMi;
                if (!sesAcikMi) {
                  _bgPlayer.stop();
                } else if (calisiyorMu) {
                  _bgPlayer.play(AssetSource('rain.mp3'), volume: 0.15);
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: _reklamYuklendiMi
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: molaModu
                  ? [const Color(0xFF065F46), Colors.black]
                  : [const Color(0xFF064E3B), Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                    color: molaModu
                        ? Colors.greenAccent.withOpacity(0.2)
                        : Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            molaModu ? Colors.greenAccent : Colors.orangeAccent,
                        width: 1)),
                child: Text(
                  molaModu ? "MOLA ZAMANI" : "ÇALIŞMA ZAMANI",
                  style: TextStyle(
                      color:
                          molaModu ? Colors.greenAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(mevcutSoz,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 16,
                        fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ayarGiris("ÇALIŞMA", _calismaController),
                const SizedBox(width: 50),
                _ayarGiris("MOLA", _molaController)
              ]),
              const SizedBox(height: 30),
              Image.asset(dinamikAgacGetir(), height: 180),
              Text(
                  "${(kalanSaniye ~/ 60).toString().padLeft(2, '0')}:${(kalanSaniye % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(
                      fontSize: 100,
                      color: Colors.white,
                      fontWeight: FontWeight.w100)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: baslatDurdur,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: calisiyorMu
                              ? Colors.orange
                              : const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15)),
                      child: Text(calisiyorMu ? "DURAKLAT" : "BAŞLAT",
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 20),
                  OutlinedButton(
                      onPressed: sifirla,
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24)),
                      child: const Text("SIFIRLA",
                          style: TextStyle(color: Colors.white))),
                ],
              ),
              const SizedBox(height: 40),
              Text("Bugünkü: $bugunkuAgacSayisi | Toplam: ${ormanim.length}",
                  style: const TextStyle(color: Colors.white30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ayarGiris(String etiket, TextEditingController ctrl) {
    return Column(children: [
      Text(etiket,
          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
      SizedBox(
          width: 50,
          child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20)))
    ]);
  }
}

class OrmanManzarasi extends StatefulWidget {
  const OrmanManzarasi({super.key});
  @override
  State<OrmanManzarasi> createState() => _OrmanManzarasiState();
}

class _OrmanManzarasiState extends State<OrmanManzarasi> {
  List<DikilenAgac> orman = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('orman_verisi');
    if (data != null) {
      final List<dynamic> decodeData = jsonDecode(data);
      setState(() {
        orman = decodeData.map((item) => DikilenAgac.fromJson(item)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Ormanımız"),
          backgroundColor: const Color(0xFF022C22)),
      backgroundColor: const Color(0xFF064E3B),
      body: orman.isEmpty
          ? const Center(
              child: Text("Burası henüz ıssız... Hadi ağaç dikmeye başla!",
                  style: TextStyle(color: Colors.white54)))
          : Padding(
              padding: const EdgeInsets.all(15.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: orman.length,
                itemBuilder: (context, index) =>
                    Image.asset(orman[index].resim),
              ),
            ),
    );
  }
}
