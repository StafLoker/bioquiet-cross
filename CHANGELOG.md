# Changelog

All notable changes to BioQuiet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-30

### Added
- **[Flutter Release]** Primera versión multiplataforma migrada a Flutter.
- Inicio de sesión y registro de usuarios mediante Firebase Authentication (Email y Google).
- Contador dinámico en tiempo real para ver la afluencia de usuarios en cada ZEPA mediante Firebase Database.
- Restricción de seguridad: subida de datos bloqueada para usuarios no autenticados (`user == null`).
- Almacenamiento local persistente (CSV) para el histórico de ruido generado.
- Menú de navegación inferior (Map / Statistics) con persistencia de estado mediante `IndexedStack`.
- Nuevo icono de la aplicación.
- Flujo CI/CD con GitHub Actions automatizado para la generación de releases en Android (APK).