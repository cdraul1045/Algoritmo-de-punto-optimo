import 'package:flutter/material.dart';
import 'dart:math';

// ==========================================================
// MODELOS DE DATOS
// ==========================================================

/// Representa un punto (X1, X2)
class Point {
  final double x;
  final double y;
  Point(this.x, this.y);

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Representa una restricción lineal: c1*X1 + c2*X2 [tipo] rhs.
class Constraint {
  final double c1; // Coeficiente de X1
  final double c2; // Coeficiente de X2
  final String type; // "<=", ">=", "="
  final double rhs; // Right-Hand Side (lado derecho)

  Constraint({required this.c1, required this.c2, required this.type, required this.rhs});

  bool isSatisfiedBy(double x, double y) {
    if (x < -1e-9 || y < -1e-9) return false;
    double val = c1 * x + c2 * y;
    switch (type) {
      case '<=':
        return val <= rhs + 1e-9;
      case '>=':
        return val >= rhs - 1e-9;
      case '=':
        return (val - rhs).abs() < 1e-9;
      default:
        return false;
    }
  }
}

/// Almacena los resultados de la optimización (Max/Min)
class OptimizationResult {
  final Point? maxPoint;
  final double? maxValue;
  final Point? minPoint;
  final double? minValue;
  final List<Point> feasibleVertices;
  final bool isFeasible;
  final bool isUnbounded;

  OptimizationResult({
    this.maxPoint,
    this.maxValue,
    this.minPoint,
    this.minValue,
    required this.feasibleVertices,
    this.isFeasible = true,
    this.isUnbounded = false,
  });
}

// ==========================================================
// FUNCIÓN PRINCIPAL DE LA APLICACIÓN
// ==========================================================

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optimizador Gráfico Lineal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
      home: const OptimizerHomePage(),
    );
  }
}

// ==========================================================
// LÓGICA DE OPTIMIZACIÓN Y UI PRINCIPAL
// ==========================================================

class OptimizerHomePage extends StatefulWidget {
  const OptimizerHomePage({super.key});

  @override
  State<OptimizerHomePage> createState() => _OptimizerHomePageState();
}

class _OptimizerHomePageState extends State<OptimizerHomePage> {
  // --- Controladores para la Función Objetivo ---
  final _c1Controller = TextEditingController(text: '80');
  final _c2Controller = TextEditingController(text: '100');

  // --- Controladores para Restricciones ---
  final _numConstraintsController = TextEditingController(text: '3');
  List<TextEditingController> _coefControllers = [];
  List<TextEditingController> _rhsControllers = [];
  List<String> _types = [];

  List<Constraint> _constraintsToDraw = [];
  OptimizationResult? _results; // Almacena los resultados de optimización

  @override
  void initState() {
    super.initState();
    _generateFields(initialLoad: true);
  }

  void _generateFields({bool initialLoad = false}) {
    final int count = int.tryParse(_numConstraintsController.text) ?? 0;
    if (count <= 0 || count > 10) {
      if (!initialLoad) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa un número entre 1 y 10.')),
        );
      }
      return;
    }
    setState(() {
      _coefControllers.forEach((c) => c.dispose());
      _rhsControllers.forEach((c) => c.dispose());

      _coefControllers = List.generate(count, (i) => TextEditingController());
      _rhsControllers = List.generate(count, (i) => TextEditingController());
      _types = List.generate(count, (_) => '>='); // Valor por defecto de la imagen

      // Valores de la imagen para la carga inicial
      if (initialLoad) {
        if (count >= 1) { _coefControllers[0].text = '2 2'; _rhsControllers[0].text = '80'; }
        if (count >= 2) { _coefControllers[1].text = '6 2'; _rhsControllers[1].text = '120'; }
        if (count >= 3) { _coefControllers[2].text = '4 12'; _rhsControllers[2].text = '240'; }
      }
      _constraintsToDraw = [];
      _results = null;
    });
  }

  // --- FUNCIÓN CENTRAL DE CÁLCULO DE VÉRTICES Y OPTIMIZACIÓN ---
  void _solveOptimization() {
    final double c1Obj = double.tryParse(_c1Controller.text) ?? 0;
    final double c2Obj = double.tryParse(_c2Controller.text) ?? 0;

    final List<Constraint> userConstraints = [];
    if (_types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero genera los campos de restricciones.')),
      );
      return;
    }

    try {
      // 1. Parsing y validación de restricciones
      for (int i = 0; i < _types.length; i++) {
        final coefsStr = _coefControllers[i].text.trim().split(RegExp(r'\s+'));

        if (coefsStr.length != 2) throw const FormatException("Los coeficientes deben ser dos números separados por espacio.");

        final c1 = double.parse(coefsStr[0]);
        final c2 = double.parse(coefsStr[1]);
        final rhs = double.parse(_rhsControllers[i].text);

        userConstraints.add(Constraint(c1: c1, c2: c2, type: _types[i], rhs: rhs));
      }

      // Añadir las restricciones de no negatividad (X1 >= 0 y X2 >= 0)
      final allConstraints = [
        ...userConstraints,
        Constraint(c1: 1, c2: 0, type: '>=', rhs: 0), // X1 >= 0
        Constraint(c1: 0, c2: 1, type: '>=', rhs: 0), // X2 >= 0
      ];

      // 2. Encontrar todos los puntos de intersección
      final List<Point> intersectionCandidates = [];
      for (int i = 0; i < allConstraints.length; i++) {
        for (int j = i + 1; j < allConstraints.length; j++) {
          final cA = allConstraints[i];
          final cB = allConstraints[j];

          // Resolver el sistema 2x2: cA.c1*x + cA.c2*y = cA.rhs; cB.c1*x + cB.c2*y = cB.rhs
          final determinant = cA.c1 * cB.c2 - cB.c1 * cA.c2;

          if (determinant.abs() > 1e-9) { // Evita líneas paralelas
            final x = (cB.c2 * cA.rhs - cA.c2 * cB.rhs) / determinant;
            final y = (cA.c1 * cB.rhs - cB.c1 * cA.rhs) / determinant;
            intersectionCandidates.add(Point(x, y));
          }
        }
      }

      // 3. Filtrar los candidatos para obtener los Vértices Factibles
      final List<Point> feasibleVertices = [];
      for (var p in intersectionCandidates) {
        bool isFeasible = allConstraints.every((c) => c.isSatisfiedBy(p.x, p.y));

        // Evitar duplicados (dentro de una tolerancia) y solo añadir puntos factibles
        if (isFeasible && !feasibleVertices.any((v) => (v.x - p.x).abs() < 1e-9 && (v.y - p.y).abs() < 1e-9)) {
          feasibleVertices.add(p);
        }
      }

      // 4. Evaluar la Función Objetivo en los vértices
      if (feasibleVertices.isEmpty) {
        setState(() {
          _results = OptimizationResult(feasibleVertices: [], isFeasible: false);
          _constraintsToDraw = userConstraints;
        });
        return;
      }

      double? maxValue, minValue;
      Point? maxPoint, minPoint;

      for (var vertex in feasibleVertices) {
        final gValue = c1Obj * vertex.x + c2Obj * vertex.y;

        if (maxValue == null || gValue > maxValue) {
          maxValue = gValue;
          maxPoint = vertex;
        }
        if (minValue == null || gValue < minValue) {
          minValue = gValue;
          minPoint = vertex;
        }
      }

      // 5. Actualizar la Interfaz con los Resultados
      setState(() {
        _constraintsToDraw = userConstraints;
        _results = OptimizationResult(
          maxPoint: maxPoint,
          maxValue: maxValue,
          minPoint: minPoint,
          minValue: minValue,
          feasibleVertices: feasibleVertices,
        );
      });

    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de formato: Asegúrese de que todos los campos sean números válidos.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _c1Controller.dispose();
    _c2Controller.dispose();
    _numConstraintsController.dispose();
    _coefControllers.forEach((c) => c.dispose());
    _rhsControllers.forEach((c) => c.dispose());
    super.dispose();
  }

  // --- WIDGETS DE LA INTERFAZ ---

  Widget _buildObjectiveFunctionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coeficientes de la función objetivo (ej: 40 60):', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c1Controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'X1'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _c2Controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'X2'),
              ),
            ),
          ],
        ),
        const Divider(height: 30),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_results == null) return const SizedBox.shrink();

    if (!_results!.isFeasible) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("❌ No se encontró región factible.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      );
    }

    // Aquí mostramos los resultados Max y Min (Ganancia)
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resultados:", style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),

            // MAXIMIZACIÓN
            if (_results!.maxValue != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("✅ GANANCIA MÁXIMA:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("X1 = ${_results!.maxPoint!.x.toStringAsFixed(2)}"),
                  Text("X2 = ${_results!.maxPoint!.y.toStringAsFixed(2)}"),
                  Text("G = ${_results!.maxValue!.toStringAsFixed(2)}"),
                  const SizedBox(height: 10),
                ],
              )
            else
              const Text("❌ No se encontró solución para la maximización."),

            // MINIMIZACIÓN
            if (_results!.minValue != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("✅ GANANCIA MÍNIMA:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("X1 = ${_results!.minPoint!.x.toStringAsFixed(2)}"),
                  Text("X2 = ${_results!.minPoint!.y.toStringAsFixed(2)}"),
                  Text("G = ${_results!.minValue!.toStringAsFixed(2)}"),
                ],
              )
            else
              const Text("❌ No se encontró solución para la minimización."),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimizador Lineal Gráfico (2 Variables)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. FUNCIÓN OBJETIVO
            _buildObjectiveFunctionSection(),

            // 2. NÚMERO DE RESTRICCIONES
            Text('Número de restricciones:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numConstraintsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'ej: 3'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _generateFields,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100),
                  child: const Text('Generar Campos'),
                ),
              ],
            ),
            const Divider(height: 30),

            // 3. CAMPOS DE RESTRICCIONES DINÁMICOS
            if (_coefControllers.isNotEmpty)
              ...List.generate(_coefControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Text('R${i+1}: '),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _coefControllers[i], // Campo único para "X1 X2"
                          decoration: const InputDecoration(hintText: 'ej: 2 2 (X1 X2)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dropdown para la condición (<=, >=, =)
                      DropdownButton<String>(
                        value: _types[i],
                        items: ['<=', '>=', '='].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _types[i] = newValue!;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _rhsControllers[i],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'RHS'),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            if (_coefControllers.isNotEmpty)
              ElevatedButton(
                onPressed: _solveOptimization, // Llamar a la función de optimización
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text('Resolver / Graficar'),
              ),

            // 4. RESULTADOS (MÁXIMA Y MÍNIMA)
            _buildResultsSection(),

            const SizedBox(height: 20),

            // 5. ÁREA DEL GRÁFICO
            if (_constraintsToDraw.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: CustomPaint(
                    painter: GraphPainter(
                      constraints: _constraintsToDraw,
                      results: _results,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// LÓGICA DE GRAFICACIÓN (CUSTOM PAINTER)
// ==========================================================

class GraphPainter extends CustomPainter {
  final List<Constraint> constraints;
  final OptimizationResult? results;

  GraphPainter({required this.constraints, this.results});

  @override
  void paint(Canvas canvas, Size size) {
    // ... (El código del CustomPainter se omite por brevedad en la explicación,
    // pero en el código completo, se actualiza para dibujar los puntos Max/Min
    // usando la información de 'results').

    // NOTA: Para el código final, asegúrese de pasar 'results' al pintor
    // y usar results.maxPoint y results.minPoint para dibujar los puntos óptimos.

    // Implementación detallada del pintor de la respuesta anterior
    // ...

    final double margin = 20.0;
    final double width = size.width - 2 * margin;
    final double height = size.height - 2 * margin;

    double maxX = 50.0;
    double maxY = 50.0;
    for (var c in constraints) {
      if (c.c1.abs() > 1e-9) maxX = max(maxX, (c.rhs / c.c1).abs() + 10);
      if (c.c2.abs() > 1e-9) maxY = max(maxY, (c.rhs / c.c2).abs() + 10);
    }
    maxX = (maxX / 10).ceil() * 10.0;
    maxY = (maxY / 10).ceil() * 10.0;

    final double scaleX = width / maxX;
    final double scaleY = height / maxY;

    Offset toCanvas(double x, double y) {
      return Offset(margin + x * scaleX, margin + height - y * scaleY);
    }

    final feasibleRegionPaint = Paint()..color = Colors.blue.withOpacity(0.2);
    const int gridSize = 100;
    final double stepX = maxX / gridSize;
    final double stepY = maxY / gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        double modelX = i * stepX;
        double modelY = j * stepY;

        bool isFeasible = true;
        for (var c in constraints) {
          if (!c.isSatisfiedBy(modelX, modelY)) {
            isFeasible = false;
            break;
          }
        }

        if (isFeasible) {
          canvas.drawRect(
            Rect.fromPoints(
                toCanvas(modelX, modelY),
                toCanvas(modelX + stepX, modelY + stepY)
            ),
            feasibleRegionPaint,
          );
        }
      }
    }

    final axisPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final textStyle = const TextStyle(color: Colors.black, fontSize: 10);

    canvas.drawLine(toCanvas(0, 0), toCanvas(maxX, 0), axisPaint);
    for (double x = 0; x <= maxX; x += maxX/5) {
      canvas.drawLine(toCanvas(x, 0), toCanvas(x, -2), axisPaint);
      _drawText(canvas, x.toStringAsFixed(0), toCanvas(x, -5), textStyle);
    }
    canvas.drawLine(toCanvas(0, 0), toCanvas(0, maxY), axisPaint);
    for (double y = 0; y <= maxY; y += maxY/5) {
      canvas.drawLine(toCanvas(0, y), toCanvas(-2, y), axisPaint);
      _drawText(canvas, y.toStringAsFixed(0), toCanvas(-5, y - 1), textStyle);
    }

    final List<Color> colors = [Colors.red, Colors.green.shade800, Colors.orange, Colors.purple];

    for (int i = 0; i < constraints.length; i++) {
      final c = constraints[i];
      final paint = Paint()..color = colors[i % colors.length]..strokeWidth = 2.0;

      Offset p1, p2;
      if (c.c2.abs() > 1e-9) {
        p1 = toCanvas(0, c.rhs / c.c2);
        p2 = toCanvas(maxX, (c.rhs - c.c1 * maxX) / c.c2);
      } else if (c.c1.abs() > 1e-9) {
        p1 = toCanvas(c.rhs / c.c1, 0);
        p2 = toCanvas(c.rhs / c.c1, maxY);
      } else {
        continue;
      }
      canvas.drawLine(p1, p2, paint);

      _drawText(canvas, "R${i+1}", p2, textStyle.copyWith(color: colors[i % colors.length], fontWeight: FontWeight.bold));
    }

    // 4. Dibujar los Puntos Óptimos
    if (results != null && results!.isFeasible) {
      final maxPoint = results!.maxPoint;
      final minPoint = results!.minPoint;

      final maxPaint = Paint()..color = Colors.green.shade700..style = PaintingStyle.fill;
      final minPaint = Paint()..color = Colors.red.shade700..style = PaintingStyle.fill;
      final vertexPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;

      // Dibujar todos los vértices factibles
      for (var p in results!.feasibleVertices) {
        canvas.drawCircle(toCanvas(p.x, p.y), 4, vertexPaint);
      }

      // Dibujar el punto máximo (más grande)
      if (maxPoint != null) {
        canvas.drawCircle(toCanvas(maxPoint.x, maxPoint.y), 8, maxPaint);
        _drawText(canvas, "Max", toCanvas(maxPoint.x + 0.5, maxPoint.y + 0.5), textStyle.copyWith(color: Colors.green, fontWeight: FontWeight.bold));
      }

      // Dibujar el punto mínimo (más grande)
      if (minPoint != null) {
        canvas.drawCircle(toCanvas(minPoint.x, minPoint.y), 8, minPaint);
        _drawText(canvas, "Min", toCanvas(minPoint.x + 0.5, minPoint.y + 0.5), textStyle.copyWith(color: Colors.red, fontWeight: FontWeight.bold));
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(position.dx, position.dy);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Redibujar si cambian las restricciones o los resultados
    return (oldDelegate as GraphPainter).constraints.length != constraints.length ||
        oldDelegate.results != results;
  }
}