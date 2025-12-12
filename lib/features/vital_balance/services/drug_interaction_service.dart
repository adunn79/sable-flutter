import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for checking drug-drug interactions using RxNorm and OpenFDA APIs
/// 
/// Free APIs, no license required:
/// - RxNorm: Normalized drug names + interaction data (DrugBank-powered)
/// - OpenFDA: Adverse events, warnings, contraindications
class DrugInteractionService {
  static const String _rxNormBase = 'https://rxnav.nlm.nih.gov/REST';
  static const String _openFdaBase = 'https://api.fda.gov/drug';
  
  /// Look up RxCUI (RxNorm Concept Unique Identifier) for a drug name
  static Future<String?> getRxCui(String drugName) async {
    try {
      final url = '$_rxNormBase/rxcui.json?name=${Uri.encodeComponent(drugName)}';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idGroup = data['idGroup'];
        if (idGroup != null && idGroup['rxnormId'] != null) {
          final rxcuis = idGroup['rxnormId'] as List;
          return rxcuis.isNotEmpty ? rxcuis.first.toString() : null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting RxCUI: $e');
      return null;
    }
  }
  
  /// Search for drugs by name (autocomplete)
  static Future<List<DrugSearchResult>> searchDrugs(String query) async {
    if (query.length < 2) return [];
    
    try {
      final url = '$_rxNormBase/drugs.json?name=${Uri.encodeComponent(query)}';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final drugGroup = data['drugGroup'];
        if (drugGroup != null && drugGroup['conceptGroup'] != null) {
          final results = <DrugSearchResult>[];
          for (final group in drugGroup['conceptGroup']) {
            if (group['conceptProperties'] != null) {
              for (final prop in group['conceptProperties']) {
                results.add(DrugSearchResult(
                  rxcui: prop['rxcui']?.toString() ?? '',
                  name: prop['name']?.toString() ?? '',
                  synonym: prop['synonym']?.toString(),
                ));
              }
            }
          }
          return results.take(10).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error searching drugs: $e');
      return [];
    }
  }
  
  /// Check interactions between multiple drugs (by RxCUI)
  static Future<List<DrugInteraction>> checkInteractions(List<String> rxcuis) async {
    if (rxcuis.length < 2) return [];
    
    try {
      final rxcuiStr = rxcuis.join('+');
      final url = '$_rxNormBase/interaction/list.json?rxcuis=$rxcuiStr';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final interactions = <DrugInteraction>[];
        
        final fullInteractionTypeGroup = data['fullInteractionTypeGroup'];
        if (fullInteractionTypeGroup != null) {
          for (final group in fullInteractionTypeGroup) {
            final fullInteractionType = group['fullInteractionType'];
            if (fullInteractionType != null) {
              for (final interaction in fullInteractionType) {
                final interactionPair = interaction['interactionPair'];
                if (interactionPair != null) {
                  for (final pair in interactionPair) {
                    interactions.add(DrugInteraction(
                      drug1: _extractDrugName(pair, 0),
                      drug2: _extractDrugName(pair, 1),
                      description: pair['description']?.toString() ?? 'Potential interaction',
                      severity: _parseSeverity(pair['severity']?.toString()),
                      source: group['sourceName']?.toString() ?? 'DrugBank',
                    ));
                  }
                }
              }
            }
          }
        }
        
        debugPrint('💊 Found ${interactions.length} drug interactions');
        return interactions;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error checking interactions: $e');
      return [];
    }
  }
  
  static String _extractDrugName(Map<String, dynamic> pair, int index) {
    final concepts = pair['interactionConcept'] as List?;
    if (concepts != null && concepts.length > index) {
      return concepts[index]['minConceptItem']['name']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }
  
  static InteractionSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'high': return InteractionSeverity.high;
      case 'moderate': return InteractionSeverity.moderate;
      case 'low': return InteractionSeverity.low;
      default: return InteractionSeverity.unknown;
    }
  }
  
  /// Get drug information from OpenFDA
  static Future<DrugInfo?> getDrugInfo(String rxcui) async {
    try {
      final url = '$_openFdaBase/label.json?search=openfda.rxcui:$rxcui&limit=1';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final result = results.first;
          return DrugInfo(
            brandName: _extractFirst(result['openfda']?['brand_name']),
            genericName: _extractFirst(result['openfda']?['generic_name']),
            manufacturer: _extractFirst(result['openfda']?['manufacturer_name']),
            dosageForm: _extractFirst(result['openfda']?['dosage_form']),
            route: _extractFirst(result['openfda']?['route']),
            indications: _extractFirst(result['indications_and_usage']),
            warnings: _extractFirst(result['warnings']),
            contraindications: _extractFirst(result['contraindications']),
            drugInteractions: _extractFirst(result['drug_interactions']),
            adverseReactions: _extractFirst(result['adverse_reactions']),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting drug info: $e');
      return null;
    }
  }
  
  static String? _extractFirst(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value?.toString();
  }
  
  /// Check single drug for interactions with user's medication list
  static Future<List<DrugInteraction>> checkAgainstMedList(
    String newDrugRxcui,
    List<String> existingRxcuis,
  ) async {
    final allRxcuis = [newDrugRxcui, ...existingRxcuis];
    final allInteractions = await checkInteractions(allRxcuis);
    
    // Filter to only interactions involving the new drug
    return allInteractions.where((i) {
      // This is simplified - in production would match by RxCUI
      return true;
    }).toList();
  }
}

/// Drug search result
class DrugSearchResult {
  final String rxcui;
  final String name;
  final String? synonym;
  
  const DrugSearchResult({
    required this.rxcui,
    required this.name,
    this.synonym,
  });
  
  @override
  String toString() => name;
}

/// Drug interaction data
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String description;
  final InteractionSeverity severity;
  final String source;
  
  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.description,
    required this.severity,
    required this.source,
  });
  
  String get severityLabel {
    switch (severity) {
      case InteractionSeverity.high: return '⚠️ High';
      case InteractionSeverity.moderate: return '⚡ Moderate';
      case InteractionSeverity.low: return '💡 Low';
      case InteractionSeverity.unknown: return '❓ Unknown';
    }
  }
}

enum InteractionSeverity { high, moderate, low, unknown }

/// Detailed drug information from OpenFDA
class DrugInfo {
  final String? brandName;
  final String? genericName;
  final String? manufacturer;
  final String? dosageForm;
  final String? route;
  final String? indications;
  final String? warnings;
  final String? contraindications;
  final String? drugInteractions;
  final String? adverseReactions;
  
  const DrugInfo({
    this.brandName,
    this.genericName,
    this.manufacturer,
    this.dosageForm,
    this.route,
    this.indications,
    this.warnings,
    this.contraindications,
    this.drugInteractions,
    this.adverseReactions,
  });
  
  String get displayName => brandName ?? genericName ?? 'Unknown Drug';
}
