# Art provenance and integration

Created 2026-11-08 using the built-in image_gen tool. No third-party downloaded art, API CLI, package install, or manual pixel editing was used. Returned image bytes were decoded directly into the SSD project. Existing source was not overwritten.

## Production-ready background
- File: ../environment/pond.png
- Size: 941 x 1672, RGB without alpha; 2,117,459 bytes.
- Render at virtual Rect2(0,0,360,640). Do not squash to 550 high.
- Shoreline at approximately source y=370 and reflection band ending near y=430. At virtual 640 high the band is y=142–165; gameplay surface y=160 fits.
- Painting, not mathematically aligned pixel art. Exact gameplay waterline should remain an independent overlay.
- Center underwater playfield deliberately clear; far edge vegetation and bottom rocks.

## Concept only: silverleaf
- File: silverleaf-concept-v1.png
- Size: 1536 x 1024, RGBA, alpha range 0–254.
- NOT production-ready: the generated alpha contains a substantial soft beige/teal halo around the fish. Do not treat the presence of alpha as clean extraction.
- Continue using original procedural fish until a built-in background-extraction edit is generated and verified.
- Nonzero alpha bounds (inclusive): [0,33,1529,1023].
- Alpha >32 bounds (inclusive): [18,347,1512,688]. This identifies the actual fish silhouette, but cropping alone does not remove the halo.
- Faces right. Approximate source anchors: mouth (1506,528), body center (890,520), tail joint (270,524).
- Whole fish, body and tail not separated.
- Roundback and moonfin were NOT generated; scope narrowed to completing pond and one fish concept.

## Visual direction
Warm gouache storybook detail, upper-left daylight, readable silhouettes.
Cream #F7EBD2; sage #7F9875; cyan #79C9C1; deep teal #286F76.
Planned remaining species: chunky orange high-backed roundback perch; deep navy moonfin with cream spots and crescent fins. These are specifications, not delivered assets.

## Pond prompt
Use case: illustration-story. Create a production 2D fishing game BACKGROUND only, portrait 9:16 canvas, intended virtual size 360x640. Warm soft gouache storybook painting with refined fine pigment and paper texture, luminous upper-left daylight. Precisely horizontal water surface at 25% image height (virtual y=160). Top quarter warm cream sky, tiny distant sage forest and hills and one tiny cabin along far shoreline, no nearby land occupying play area. Below surface cyan-to-teal underwater gradient filling all remaining image. Low-contrast underwater rocks and delicate plants ONLY at far left/right edges and bottommost edge. From x=15% to 85%, below the surface down to y=85%, keep almost empty clear water, beautiful subtle light gradients. Small quiet detailed natural accents, cozy sophisticated palette cream #F7EBD2, sage #7F9875, cyan #79C9C1, deep teal #286F76. Flat side view cross-section of pond, NOT aerial perspective. No fish, humans, rod, fishing line, boat, text, UI, buttons, frames, logos, watermark. Clean single continuous background illustration.

## Silverleaf prompt
Use case: illustration-story. Production 2D fishing-game sprite, one single slender SILVERLEAF fish, facing RIGHT in exact flat side profile, isolated genuine transparent background. One intact fish including its forked tail on the left, slim graceful silver-cream body with teal blue-green back, fine small painted scales, gentle dark clear eye, very subtle golden gill, small translucent-looking fins, rich but readable silhouette. Warm storybook gouache hand-painted soft grain detail, coherent cozy cyan-teal pond palette, upper-left light. Entire fish visible with tail, body, fins; fill canvas width with only 5% padding all sides. Canvas landscape 3:2, fish long and thin height about 40% of canvas. Use compact output around 768x512 if possible. No water, bubbles, ground shadow, fishing equipment, labels, lettering, UI, frame, watermark. Single fish, not sheet. Background must have actual alpha transparency.

## Next cleanup prompt (not executed)
Use the saved silverleaf concept as edit target. Preserve the entire fish silhouette, scales, eye, gills, colors and fins exactly. Remove all beige and teal glow, shadow, haze and background pixels outside the fish, including near-transparent noise. Output genuinely transparent background with zero alpha beyond the fish edge. Keep subtle antialiasing only at the immediate silhouette. Do not add objects or modify fish anatomy.
