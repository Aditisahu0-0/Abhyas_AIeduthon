import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../utils/app_theme.dart';

class MindMapScreen extends StatefulWidget {
  final String title;
  final String jsonData;

  const MindMapScreen({super.key, required this.title, required this.jsonData});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final Graph graph = Graph()..isTree = true;
  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  @override
  void initState() {
    super.initState();
    _buildGraph();

    builder
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

  void _buildGraph() {
    try {
      final jsonMap = json.decode(widget.jsonData);
      final rootNode = Node.Id(jsonMap['id']);
      graph.addNode(rootNode);
      _parseChildren(jsonMap, rootNode);
    } catch (e) {
      print('Error parsing graph JSON: $e');
    }
  }

  void _parseChildren(Map<String, dynamic> parentJson, Node parentNode) {
    if (parentJson.containsKey('children')) {
      for (var childJson in parentJson['children']) {
        final childNode = Node.Id(childJson['id']);
        graph.addEdge(parentNode, childNode);
        _parseChildren(childJson, childNode);
      }
    }
  }

  String _getLabel(Node node) {
    try {
      final jsonMap = json.decode(widget.jsonData);
      return _findLabel(jsonMap, node.key!.value);
    } catch (e) {
      return 'Node';
    }
  }

  String _findLabel(Map<String, dynamic> data, dynamic id) {
    if (data['id'] == id) return data['label'] ?? 'Unknown';
    if (data.containsKey('children')) {
      for (var child in data['children']) {
        final label = _findLabel(child, id);
        if (label != 'Unknown') return label;
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.01,
              maxScale: 5.6,
              child: GraphView(
                graph: graph,
                algorithm: BuchheimWalkerAlgorithm(
                  builder,
                  TreeEdgeRenderer(builder),
                ),
                paint: Paint()
                  ..color = Colors.green
                  ..strokeWidth = 1
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  var a = node.key!.value as String;
                  var label = _getLabel(node);

                  return _buildNodeWidget(label);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppTheme.cyanAccent.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
