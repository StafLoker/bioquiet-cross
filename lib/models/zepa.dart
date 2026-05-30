class NoiseThresholds {
  final int dbSafe;
  final int dbWarning;

  NoiseThresholds({required this.dbSafe, required this.dbWarning});

  factory NoiseThresholds.fromJson(Map<String, dynamic> json) {
    return NoiseThresholds(
      dbSafe: json['dbSafe'] ?? 55, // Nivel óptimo estándar
      dbWarning: json['dbWarning'] ?? 70, // Límite de advertencia estándar
    );
  }
}

class Habitat {
  final String? code;
  final String? description;
  final bool? priority;
  final double? coverHa;
  final String? representativity;
  final String? conservation;
  final String? globalAssessment;

  Habitat({
    this.code,
    this.description,
    this.priority,
    this.coverHa,
    this.representativity,
    this.conservation,
    this.globalAssessment,
  });

  factory Habitat.fromJson(Map<String, dynamic> json) {
    return Habitat(
      code: json['code'],
      description: json['description'],
      priority: json['priority'],
      coverHa: (json['coverHa'] as num?)?.toDouble(),
      representativity: json['representativity'],
      conservation: json['conservation'],
      globalAssessment: json['globalAssessment'],
    );
  }
}

class Species {
  final String? code;
  final String? name;
  final String? group;
  final String? populationType;
  final String? abundance;
  final String? conservation;
  final String? global;

  Species({
    this.code,
    this.name,
    this.group,
    this.populationType,
    this.abundance,
    this.conservation,
    this.global,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      code: json['code'],
      name: json['name'],
      group: json['group'],
      populationType: json['populationType'],
      abundance: json['abundance'],
      conservation: json['conservation'],
      global: json['global'],
    );
  }
}

class Impact {
  final String? code;
  final String? description;
  final String? intensity;
  final String? occurrence;
  final String? type;

  Impact({
    this.code,
    this.description,
    this.intensity,
    this.occurrence,
    this.type,
  });

  factory Impact.fromJson(Map<String, dynamic> json) {
    return Impact(
      code: json['code'],
      description: json['description'],
      intensity: json['intensity'],
      occurrence: json['occurrence'],
      type: json['type'],
    );
  }
}

class Management {
  final String? orgName;
  final String? orgEmail;
  final String? planUrl;
  final String? measures;

  Management({this.orgName, this.orgEmail, this.planUrl, this.measures});

  factory Management.fromJson(Map<String, dynamic> json) {
    return Management(
      orgName: json['orgName'],
      orgEmail: json['orgEmail'],
      planUrl: json['planUrl'],
      measures: json['measures'],
    );
  }
}

class GeoJsonGeometry {
  final String type;
  final dynamic coordinates;

  GeoJsonGeometry({required this.type, required this.coordinates});

  factory GeoJsonGeometry.fromJson(Map<String, dynamic> json) {
    return GeoJsonGeometry(
      type: json['type'] ?? 'Polygon',
      coordinates: json['coordinates'],
    );
  }
}

class Zepa {
  final String id;
  final String name;
  final NoiseThresholds noiseThresholds;
  final double? areaHa;
  final String? dateSpa;
  final String? spaLegalRef;
  final String? description;
  final String? quality;
  final List<Habitat> habitats;
  final List<Species> species;
  final List<Impact> impacts;
  final List<Management> management;
  final GeoJsonGeometry geometry;

  Zepa({
    required this.id,
    required this.name,
    required this.noiseThresholds,
    this.areaHa,
    this.dateSpa,
    this.spaLegalRef,
    this.description,
    this.quality,
    required this.habitats,
    required this.species,
    required this.impacts,
    required this.management,
    required this.geometry,
  });

  factory Zepa.fromJson(Map<String, dynamic> json) {
    return Zepa(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Espacio Natural',
      noiseThresholds: NoiseThresholds.fromJson(json['noiseThresholds'] ?? {}),
      areaHa: (json['areaHa'] as num?)?.toDouble(),
      dateSpa: json['dateSpa'],
      spaLegalRef: json['spaLegalRef'],
      description: json['description'],
      quality: json['quality'],
      habitats:
          (json['habitats'] as List?)
              ?.map((e) => Habitat.fromJson(e))
              .toList() ??
          [],
      species:
          (json['species'] as List?)
              ?.map((e) => Species.fromJson(e))
              .toList() ??
          [],
      impacts:
          (json['impacts'] as List?)?.map((e) => Impact.fromJson(e)).toList() ??
          [],
      management:
          (json['management'] as List?)
              ?.map((e) => Management.fromJson(e))
              .toList() ??
          [],
      geometry: GeoJsonGeometry.fromJson(json['geometry'] ?? {}),
    );
  }
}
