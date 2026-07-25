# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Design-system maintainers who define, implement, test, and evolve the ClaraLight component language for Flutter applications. The gallery is a reference and validation surface for these maintainers rather than the primary product.

## Product Purpose

ClaraLight provides a reusable Flutter implementation of a coherent design language. It gives maintainers shared theme tokens, typography, interaction behavior, surfaces, controls, inputs, containers, overlays, scrolling primitives, lists, navigation, and status indicators so applications can use the same system instead of rebuilding each control independently.

Success means the package is dependable as a shared implementation: its exported widgets behave consistently across Flutter target platforms, its interaction and accessibility behavior can be verified, and the gallery makes the component system easy to inspect and exercise.

## Positioning

ClaraLight is a reusable Flutter implementation of the ClaraLight design language, with the Facetory Figma/source application as its reference. Its value is in encoding the language as composable Flutter APIs and interaction primitives, including layered surfaces, theme tokens, bundled typography, spring-based interaction, progressive scrolling, and adaptive overlays, rather than offering only static visual guidance or one-off screens.

## Operating Context

Maintainers work primarily in the `packages/claralight_ui` package and use `packages/claralight_ui_gallery` to inspect and interact with the component set. The gallery presents controls, inputs, scrolling, lists, toolbars, tabs, color picking, progress and status indicators, tooltips, popovers, sheets, dialogs, and menus in one runnable surface. Widget tests and focused component tests provide behavioral contracts for the package and gallery.

Consumers wrap application content in `CLTheme` and compose the exported `CL*` widgets with Flutter application code. The current workspace is unpublished (`publish_to: none`); future distribution and publishing intent remain undecided.

## Capabilities and Constraints

- The public package exports theme and token types, fonts, surfaces, buttons, controls, inputs, scrolling primitives, lists, containers, overlays, menus, navigation, and indicators through `claralight_ui.dart`.
- The package supports both dark and light color schemes and allows applications to provide custom theme data.
- Components include interactive motion, frosted floating layers, responsive overflow behavior, progressive edge effects for scrolling, and semantic control states.
- The implementation is intended to run across Flutter target platforms as a pure Dart/Flutter package without native implementation dependencies.
- Reduced-motion and accessibility behavior are durable requirements. Platform-specific accessibility details and the formal conformance target are open decisions.
- Bundled font assets are part of the implementation and their redistribution/licensing facts must remain traceable in `packages/claralight_ui/fonts/FONTS.md`.
- The package currently depends on Flutter, `progressive_blur`, and `visibility_detector`; dependency changes must preserve the cross-platform package constraint.

## Brand Commitments

- The product names `ClaraLight`, `Claralight Design`, and `claralight_ui` are existing identity commitments.
- The Facetory Figma/source application is the reference for the ClaraLight implementation.
- The bundled font families and their documented licenses are existing assets, not placeholders to be replaced casually.

## Evidence on Hand

- Public API entry point: `packages/claralight_ui/lib/claralight_ui.dart`.
- Core theme and token implementation: `packages/claralight_ui/lib/src/theme/`.
- Bundled fonts and source/license record: `packages/claralight_ui/fonts/` and `packages/claralight_ui/fonts/FONTS.md`.
- Runnable reference gallery: `packages/claralight_ui_gallery/lib/main.dart` and its `lib/src/` sections.
- Package and gallery behavior tests: `packages/claralight_ui/test/` and `packages/claralight_ui_gallery/test/`.
- The repository contains no confirmed customer data, testimonials, usage metrics, or production application content. Future work must not fabricate them.

## Product Principles

- Encode the design language as reusable, composable Flutter APIs rather than screen-specific copies.
- Treat the gallery and tests as inspectable evidence of component behavior, not as decorative documentation.
- Preserve cross-platform Flutter behavior while keeping platform-specific implementation out of the core package.
- Keep interaction quality, reduced-motion behavior, and accessible semantics part of the component contract.
- Maintain traceable design-source and font-licensing commitments as the system evolves.

## Accessibility & Inclusion

Reduced-motion behavior and accessibility support are required product qualities. The current implementation detects disabled animations and includes focused accessibility and reduced-motion tests. The exact platform matrix, formal accessibility standard, and any additional inclusion requirements remain open decisions.
