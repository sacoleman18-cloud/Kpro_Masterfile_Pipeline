# Changelog

All notable changes to the KPro Masterfile Pipeline will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-01-31

### Added
- Comprehensive R package structure with DESCRIPTION file
- Git attributes configuration for proper file handling
- Contributing guidelines (CONTRIBUTING.md)
- Code of Conduct (CODE_OF_CONDUCT.md)
- Changelog tracking (this file)
- Installation guide (INSTALL.md)
- Deprecated legacy README with migration guide

### Documentation
- Updated project documentation structure
- Added comprehensive standards documentation (9 docs)
- Created architectural overview in README.md
- Added YAML parameter guide

### Infrastructure
- Established modular function library structure (21 function modules)
- Implemented 7-workflow pipeline architecture
- Added testthat testing framework with 6 test suites
- Created artifact registry for reproducibility tracking

## [2.0.0] - 2025-12

### Added
- Complete pipeline refactor to 7-workflow architecture
- Quarto-based reporting system (Workflow 07)
- Pre-computed artifacts (RDS-based) for deterministic outputs
- Comprehensive exploratory plots (26 visualizations across 4 categories)
- GT table formatting for publication-grade summaries
- YAML-based configuration system
- Detector mapping functionality
- Timezone conversion utilities
- Release bundle generation (ZIP artifacts)
- Artifact registry with SHA256 hashing
- Validation reporting framework

### Changed
- Separated computation (Workflows 01-06) from presentation (Workflow 07)
- Migrated to structured function modules (7 categories)
- Enhanced schema detection for KPro v1/v2/v3
- Improved checkpoint system with timestamps
- Standardized output directory structure

### Deprecated
- Legacy 2-workflow system (01_build_kpro_master.R, 02_append_previous_masters.R)
- Manual CSV manipulation workflow

## [1.0.0] - Initial Release

### Added
- Basic KPro CSV ingestion (recursive)
- Column normalization across KPro versions
- UTC to CST conversion
- Noise filtering
- Master file export functionality
- Optional previous master file appending

---

## Version Naming Convention

- **Major version (X.0.0)**: Breaking changes to data contracts, workflow structure, or API
- **Minor version (0.X.0)**: New features, backward-compatible changes
- **Patch version (0.0.X)**: Bug fixes, documentation updates, minor refinements

---

## Upcoming Changes (Roadmap)

### [3.0.0] - Future Major Release
- Shiny application GUI wrapper
- JSON API layer for programmatic access
- Read-only mode enforcement in Shiny
- Config-driven behavior expansion
- Enhanced execution profiles and diagnostics

### [2.2.0] - Next Minor Release
- Expanded test coverage (target: 80%+)
- GitHub Actions CI/CD pipeline
- Code linting integration (lintr)
- Additional plot customization options
- Improved validation report HTML formatting

### [2.1.1] - Next Patch
- Bug fixes from user feedback
- Documentation clarifications
- Plot label improvements
- Table formatting refinements

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
