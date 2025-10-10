Optimizador Lineal Gráfico (2 Variables)
Una aplicación móvil desarrollada con Flutter que resuelve problemas de Programación Lineal (PL) de dos variables (X
1
​
y X
2
​
) utilizando el Método Gráfico. Calcula los puntos de la región factible, determina la solución óptima (Máxima y Mínima Ganancia/Costo) y visualiza la región factible y los puntos clave.

🚀 Características Principales
Método Gráfico: Solución de problemas de PL limitados a dos variables.

Diseño Interactivo: Interfaz limpia con diseño Material 3 y tarjetas agrupadas.

Entrada Dinámica: Permite al usuario generar dinámicamente campos de restricción.

Tipos de Restricción: Soporte para restricciones de menor o igual (<=), mayor o igual (>=) e igualdad (=).

Detección de Óptimos: Muestra las coordenadas y el valor de la función objetivo para las soluciones Máxima y Mínima.

Manejo de No-Acotamiento: Detecta y notifica cuando la solución de maximización es no acotada (infinita) en regiones abiertas.

Visualización: Gráfico de la región factible y marcadores para los puntos óptimos.

🛠️ Instalación y Requisitos
Para clonar y ejecutar este proyecto, necesitas tener instalado Flutter y Dart.

Requisitos Previos
Flutter SDK: Versión 3.19.x o superior (se recomienda la última versión estable).

Dart SDK: Viene incluido con Flutter.

Un editor de código: Visual Studio Code o Android Studio con plugins de Flutter/Dart.

Pasos para Ejecutar
Clonar el repositorio:

Bash

git clone [TU_URL_DEL_REPOSITORIO]
cd optimizador-lineal-grafico
Instalar dependencias:

Bash

flutter pub get
Ejecutar la aplicación:
Asegúrate de tener un emulador abierto o un dispositivo conectado.

Bash

flutter run
⚙️ Guía de Uso
La aplicación está diseñada para ser intuitiva, replicando la estructura de un solver de escritorio.

1. Entrada de la Función Objetivo
   Introduce los coeficientes de las variables X
   1
   ​
   y X
   2
   ​
   que definen tu función objetivo (por ejemplo, 80 y 100).

2. Definición de Restricciones
   Introduce el Número de restricciones (ej: 3).

Pulsa el botón "Generar Campos".

Para cada restricción:

Campo Izquierdo: Introduce los coeficientes de X
1
​
y X
2
​
separados por un espacio (ej: 2 2).

Dropdown: Selecciona el tipo de desigualdad/igualdad (<=, >=, =).

Campo Derecho (RHS): Introduce el valor del lado derecho (ej: 80).

3. Solución
   Presiona el botón "Resolver / Graficar" (color verde).

La aplicación:

Calcula los vértices de la región factible.

Evalúa la función objetivo en esos vértices.

Muestra la Ganancia Máxima y Mínima en la sección de Resultados.

Dibuja el área factible en el gráfico, marcando los puntos óptimos.

⚠️ Manejo de Errores
Formato de Coeficientes: Si los coeficientes no tienen el formato [número] [espacio] [número] (ej: 2 2), la aplicación mostrará un error.

No hay Solución Máxima: Si el problema es de minimización con una región factible abierta (típico con solo restricciones >=), el campo de Ganancia Máxima mostrará: "❌ No se encontró solución para la maximización".

📂 Estructura del Código
El proyecto es sencillo y se mantiene en gran medida dentro de main.dart, utilizando clases y métodos lógicos para mantener la claridad.

Clase / Método	Función
Point, Constraint, OptimizationResult	Modelos de datos para variables, restricciones y resultados.
_solveOptimization()	Motor de Cálculo. Resuelve el sistema de ecuaciones, filtra los vértices factibles y realiza la evaluación Max/Min.
_buildResultsSection()	Muestra los resultados de optimización (Máxima/Mínima) y maneja la detección de no-acotamiento.
GraphPainter	Motor Gráfico. Clase CustomPainter que dibuja las líneas de restricción, sombrea la región factible y marca los puntos Max/Min.