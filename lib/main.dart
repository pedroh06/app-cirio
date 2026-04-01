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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final String apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjVmMGVkMDQ0NjYxNjRhMTc5ZmUxNGM3YzRhMDFiNjBhIiwiaCI6Im11cm11cjY0In0=';

  final LatLng catedral = LatLng(-1.4557, -48.5047);
  final LatLng basilica = LatLng(-1.4526, -48.4812);
  final LatLng colegio = LatLng(-1.4519, -48.4796);

  final List<LatLng> pontosRotaCirio = [
    LatLng(-1.4557, -48.5047),
    LatLng(-1.4556, -48.5048),
    LatLng(-1.4553, -48.5044),
    LatLng(-1.4539, -48.5030),
    LatLng(-1.4533, -48.5034),
    LatLng(-1.4528, -48.5038),
    LatLng(-1.4497, -48.5005),
    LatLng(-1.4498, -48.5005),
    LatLng(-1.4492, -48.4995), //
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

  List<LatLng> rotaAtual = [];
  LatLng? localizacaoUsuario;
  String legendaMapa = '';
  bool carregando = false;

  Future<List<LatLng>> buscarRota(LatLng inicio, LatLng fim) async {
    final url =
        'https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$apiKey&start=${inicio.longitude},${inicio.latitude}&end=${fim.longitude},${fim.latitude}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data['features'][0]['geometry']['coordinates'] as List;
      return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    } else {
      throw Exception('Erro ao buscar rota');
    }
  }

Future<void> mostrarRotaCirio() async {
    setState(() {
      legendaMapa = 'Rota do Círio';
      rotaAtual = pontosRotaCirio;
    });
  }

  Future<void> mostrarRotaTrasladacao() async {
    setState(() {
      legendaMapa = 'Rota da Trasladação';
      rotaAtual = pontosRotaCirio.reversed.toList();
    });
  }

  Future<void> mostrarMinhaRota() async {
    setState(() {
      carregando = true;
      legendaMapa = 'Minha rota até o início';
    });

    LocationPermission permissao = await Geolocator.requestPermission();
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de localização negada')),
      );
      setState(() => carregando = false);
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      final rota = await buscarRota(userLatLng, catedral);
      setState(() {
        localizacaoUsuario = userLatLng;
        rotaAtual = rota;
      });
    } catch (e) {
      mostrarErro();
    } finally {
      setState(() => carregando = false);
    }
  }

  void mostrarErro() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro ao buscar rota. Tente novamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Círio de Nazaré 2025'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: carregando ? null : mostrarRotaCirio,
                  child: const Text('Círio'),
                ),
                ElevatedButton(
                  onPressed: carregando ? null : mostrarRotaTrasladacao,
                  child: const Text('Trasladação'),
                ),
                ElevatedButton(
                  onPressed: carregando ? null : mostrarMinhaRota,
                  child: const Text('Minha rota'),
                ),
              ],
            ),
          ),
          if (carregando)
            const LinearProgressIndicator(),
          if (legendaMapa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                legendaMapa,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: catedral,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.cirio_app',
                ),
                if (rotaAtual.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: rotaAtual,
                        strokeWidth: 4,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: catedral,
                      width: 80,
                      height: 80,
                      child: const Column(
                        children: [
                          Icon(Icons.location_pin, color: Colors.red, size: 36),
                          Text('Início', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (localizacaoUsuario != null)
                      Marker(
                        point: localizacaoUsuario!,
                        width: 80,
                        height: 80,
                        child: const Column(
                          children: [
                            Icon(Icons.person_pin_circle, color: Colors.green, size: 36),
                            Text('Você', style: TextStyle(fontSize: 10)),
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
}