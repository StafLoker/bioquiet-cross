class NoiseThresholds {
  final int dbSafe;
  final int dbWarning;

  NoiseThresholds({required this.dbSafe, required this.dbWarning});
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
}

class Management {
  final String? orgName;
  final String? orgEmail;
  final String? planUrl;
  final String? measures;

  Management({
    this.orgName,
    this.orgEmail,
    this.planUrl,
    this.measures,
  });
}

class GeoJsonGeometry {
  final String type;
  final dynamic coordinates;

  GeoJsonGeometry({required this.type, required this.coordinates});
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
}