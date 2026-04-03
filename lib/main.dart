import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Círio de Nazaré',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapaPage(),
    );
  }
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  // API key do OpenRouteService (em produção, usar variável de ambiente)
  final String apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjVmMGVkMDQ0NjYxNjRhMTc5ZmUxNGM3YzRhMDFiNjBhIiwiaCI6Im11cm11cjY0In0=';

  // === PONTOS DE REFERÊNCIA ===
  // Catedral Metropolitana (Cidade Velha) - ponto de INÍCIO do Círio
  final LatLng catedral = LatLng(-1.4557, -48.5047);

  // Basílica de Nazaré - ponto de CHEGADA do Círio
  final LatLng basilica = LatLng(-1.4528, -48.4811);

  // Colégio Gentil Bittencourt - ponto de saída da Trasladação
  final LatLng colegioGentil = LatLng(-1.4519, -48.4796);

  // === ROTA DO CÍRIO ===
  // Catedral Metropolitana -> Basílica de Nazaré (domingo de manhã)
  // OBS: Pedro está refinando esses pontos
  final List<LatLng> pontosRotaCirio = [
    LatLng(-1.4557, -48.5047),
    LatLng(-1.4556, -48.5048),
    LatLng(-1.4553, -48.5044),
    LatLng(-1.4539, -48.5030),
    LatLng(-1.4533, -48.5034),
    LatLng(-1.4528, -48.5038),
    LatLng(-1.4497, -48.5005),
    LatLng(-1.4498, -48.5005),
    LatLng(-1.4492, -48.4995),
    LatLng(-1.4508, -48.4980),
    LatLng(-1.4520, -48.4969),
    LatLng(-1.4516, -48.4964),
    LatLng(-1.4521, -48.4960),
    LatLng(-1.4532, -48.4943),
    LatLng(-1.4541, -48.4928),
    LatLng(-1.4538, -48.4925),
    LatLng(-1.4522, -48.4828),
    LatLng(-1.4521, -48.4814),
    LatLng(-1.4529, -48.4814),
    LatLng(-1.4528, -48.4811),
  ];

  // === ROTA DA TRASLADAÇÃO ===
  // Colégio Gentil -> Catedral Metropolitana (sábado à noite)
  // Trajeto: Av. Nazaré → Av. Presidente Vargas → Blvd. Castilho França
  //          → Av. Portugal → Rua Padre Champagnat → Catedral da Sé
  final List<LatLng> pontosRotaTrasladacao = [
    LatLng(-1.452115, -48.479615),  // Colégio Gentil (saída)
    LatLng(-1.452145, -48.480599),  // Av. Nazaré
    LatLng(-1.452207, -48.482821),  // Av. Nazaré
    LatLng(-1.452281, -48.486444),  // Av. Nazaré
    LatLng(-1.452875, -48.488857),  // Av. Nazaré
    LatLng(-1.454215, -48.492794),  // chegando na Pres. Vargas
    LatLng(-1.453209, -48.494388),  // Av. Presidente Vargas
    LatLng(-1.452211, -48.496069),  // Av. Presidente Vargas
    LatLng(-1.450452, -48.497190),  // Av. Presidente Vargas
    LatLng(-1.449148, -48.498009),  // Av. Presidente Vargas
    LatLng(-1.447974, -48.498750),  // Av. Presidente Vargas
    LatLng(-1.448922, -48.499771),  // Blvd. Castilho França
    LatLng(-1.449765, -48.500600),  // Blvd. Castilho França
    LatLng(-1.451061, -48.502084),  // Blvd. Castilho França
    LatLng(-1.452306, -48.503322),  // Av. Portugal
    LatLng(-1.452821, -48.503842),  // Av. Portugal
    LatLng(-1.453486, -48.503446),  // Rua Padre Champagnat
    LatLng(-1.454452, -48.503579),  // Rua Padre Champagnat
    LatLng(-1.455097, -48.504163),  // chegando na Catedral
    LatLng(-1.455574, -48.504624),  // Catedral da Sé
    LatLng(-1.455893, -48.504552),  // Catedral da Sé (chegada)
  ];

  // === ESTADO DO APP ===
  List<LatLng> rotaAtual = [];
  LatLng? localizacaoUsuario;
  String legendaMapa = '';
  Color corRota = Colors.blue;
  bool carregando = false;

  // Controller do mapa pra poder reposicionar a câmera
  final MapController mapController = MapController();

  // === FUNÇÕES ===

  /// Busca rota real (caminhando) via OpenRouteService
  Future<List<LatLng>> buscarRota(LatLng inicio, LatLng fim) async {
    final url =
        'https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$apiKey&start=${inicio.longitude},${inicio.latitude}&end=${fim.longitude},${fim.latitude}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['features'][0]['geometry']['coordinates'] as List;
      return coords
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();
    } else {
      throw Exception('Erro ao buscar rota: ${response.statusCode}');
    }
  }

  /// Exibe a rota do Círio no mapa
  void mostrarRotaCirio() {
    setState(() {
      legendaMapa = 'Rota do Círio de Nazaré';
      rotaAtual = pontosRotaCirio;
      corRota = Colors.blue;
    });

    // Centraliza o mapa na rota
    mapController.move(catedral, 14);
  }

  /// Exibe a rota da Trasladação no mapa
  void mostrarRotaTrasladacao() {
    setState(() {
      legendaMapa = 'Rota da Trasladação';
      rotaAtual = pontosRotaTrasladacao;
      corRota = Colors.purple;
    });

    // Centraliza no Colégio Gentil (início da Trasladação)
    mapController.move(colegioGentil, 14);
  }

  /// Busca localização do usuário e traça rota até o ponto inicial do Círio
  Future<void> mostrarMinhaRota() async {
    setState(() {
      carregando = true;
      legendaMapa = 'Calculando sua rota...';
    });

    // Verifica permissão de localização
    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de localização negada.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        carregando = false;
        legendaMapa = '';
      });
      return;
    }

    try {
      // Pega posição atual
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final userLatLng = LatLng(pos.latitude, pos.longitude);

      // Busca rota via API
      final rota = await buscarRota(userLatLng, catedral);

      setState(() {
        localizacaoUsuario = userLatLng;
        rotaAtual = rota;
        legendaMapa = 'Sua rota até o início do Círio';
        corRota = Colors.green;
      });

      // Centraliza no usuário
      mapController.move(userLatLng, 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao buscar rota. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        legendaMapa = '';
      });
    } finally {
      setState(() => carregando = false);
    }
  }

  // === INTERFACE ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Círio de Nazaré 2025'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barra de botões
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBotao(
                  label: 'Círio',
                  icone: Icons.church,
                  cor: Colors.blue,
                  onPressed: carregando ? null : mostrarRotaCirio,
                ),
                _buildBotao(
                  label: 'Trasladação',
                  icone: Icons.nights_stay,
                  cor: Colors.purple,
                  onPressed: carregando ? null : mostrarRotaTrasladacao,
                ),
                _buildBotao(
                  label: 'Minha Rota',
                  icone: Icons.navigation,
                  cor: Colors.green,
                  onPressed: carregando ? null : mostrarMinhaRota,
                ),
              ],
            ),
          ),

          // Indicador de carregamento
          if (carregando) const LinearProgressIndicator(),

          // Legenda da rota atual
          if (legendaMapa.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: corRota.withOpacity(0.1),
              child: Text(
                legendaMapa,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: corRota,
                  fontSize: 14,
                ),
              ),
            ),

          // Mapa
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: catedral,
                initialZoom: 14,
              ),
              children: [
                // Tiles do OpenStreetMap
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_cirio',
                ),

                // Polyline da rota atual
                if (rotaAtual.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: rotaAtual,
                        strokeWidth: 5,
                        color: corRota,
                      ),
                    ],
                  ),

                // Marcadores
                MarkerLayer(
                  markers: [
                    // Catedral (início do Círio)
                    Marker(
                      point: catedral,
                      width: 100,
                      height: 60,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_pin,
                              color: Colors.red, size: 36),
                          Text('Catedral',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ],
                      ),
                    ),

                    // Basílica de Nazaré (chegada do Círio)
                    Marker(
                      point: basilica,
                      width: 100,
                      height: 60,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_pin,
                              color: Colors.orange, size: 36),
                          Text('Basílica',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                    ),

                    // Localização do usuário (se disponível)
                    if (localizacaoUsuario != null)
                      Marker(
                        point: localizacaoUsuario!,
                        width: 80,
                        height: 60,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_pin_circle,
                                color: Colors.green, size: 36),
                            Text('Você',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper pra criar os botões de forma consistente
  Widget _buildBotao({
    required String label,
    required IconData icone,
    required Color cor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
