// Blackwall: a hostile data barrier around the focused window.
// A black wall of writhing tissue pushes outward from the edge, threaded with hot
// veins, lashing tendrils, scrolling data blocks and occasional glitch tears.
//
// Colours: with palette = true (shipped) the wall follows the theme, using
// accent_primary for the wall and accent_secondary for data and glitch static.
// With palette = false it uses the manual COL_* colours below.
// A black wall of writhing crimson tissue pushes outward from the edge, threaded
// with hot veins, scrolling data blocks and occasional glitch tears.

// Reach of the wall beyond the window edge, in logical px (keep below padding).
const float WALL_MIN = 10.0;
const float WALL_MAX = 22.0;
// Thin filaments that lash out past the wall, in logical px beyond the front.
const float TENDRIL_REACH = 6.0;
// How fast the wall writhes and how far its features drift per second.
const float WRITHE_SPEED = 0.35;
const float CRAWL_SPEED = 14.0; // logical px per second along the edge
// Bright vein thickness (0..0.2) and brightness.
const float VEIN_WIDTH = 0.09;
const float VEIN_GAIN = 1.4;
// Data blocks: cell size in logical px, density 0..1, outward scroll speed.
const float DATA_CELL = 3.0;
const float DATA_DENSITY = 0.16;
const float DATA_SPEED = 18.0;
// Glitch tears: seconds between chances, chance per period, sideways jump in px.
const float GLITCH_PERIOD = 2.5;
const float GLITCH_CHANCE = 0.55;
const float GLITCH_PX = 18.0;
// Breathing pulse of the whole wall, in seconds per beat.
const float PULSE_PERIOD = 3.2;

// Manual colours, used when palette = false. Straight RGB, 0..1.
const vec3 COL_BLACK = vec3(0.012, 0.0, 0.004);  // wall body
const vec3 COL_DEEP = vec3(0.30, 0.0, 0.025);    // dark glow near the edge
const vec3 COL_MAIN = vec3(1.0, 0.03, 0.08);     // veins, tendrils, edge line
const vec3 COL_HOT = vec3(1.0, 0.55, 0.52);      // brightest highlights
const vec3 COL_DATA = vec3(1.0, 0.29, 0.30);     // data blocks and glitch static

// Theme mode: how each layer is derived from the accents.
const float DEEP_SHARE = 0.28;   // dark glow, as a fraction of accent_primary
const float BLACK_SHARE = 0.015; // wall body; keep tiny so the wall stays black
const float HOT_WHITE = 0.65;    // how far highlights blend from the accent toward white
const float DATA_ACCENT = 0.7;   // 0 = data uses accent_primary, 1 = fully accent_secondary

float bf_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bf_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = bf_hash(i);
    float b = bf_hash(i + vec2(1.0, 0.0));
    float c = bf_hash(i + vec2(0.0, 1.0));
    float d = bf_hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float bf_fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * bf_noise(p);
        p = p * 2.03 + vec2(17.0, 9.0);
        a *= 0.5;
    }
    return v;
}

// x: wall coverage, y: vein brightness, z: data brightness. s is perimeter px, d is px outside the edge.
vec3 bf_field(float s, float d, float t) {
    float w = t * WRITHE_SPEED;
    vec2 q = vec2(s / 26.0 - t * CRAWL_SPEED / 26.0, d / 14.0);
    // Domain warp gives the slow, organic writhing.
    vec2 warp = vec2(bf_fbm(q + vec2(0.0, w)), bf_fbm(q + vec2(5.2, -w)));
    float n = bf_fbm(q * 1.4 + 1.8 * warp + vec2(0.0, -w * 1.5));

    // Ragged outer front: spikes of the wall reach out and recede.
    float spike = bf_fbm(vec2(s / 11.0, w * 1.3));
    float reach = mix(WALL_MIN, WALL_MAX, smoothstep(0.3, 0.7, spike));
    float front = d + 7.0 * (n - 0.5);
    float cover = 1.0 - smoothstep(reach * 0.8, reach, front);

    // Tendrils: narrow ridges of a slow noise along the edge, tapering as they leave the wall.
    float ridge = abs(bf_noise(vec2(s / 9.0 + 0.6 * warp.x, w * 0.8)) - 0.5);
    float lash = 1.0 - smoothstep(0.0, 0.035 + 0.02 * exp(-d / 8.0), ridge);
    float len = reach + TENDRIL_REACH * bf_noise(vec2(s / 5.0, w));
    lash *= 1.0 - smoothstep(len - 3.0, len, d);

    // Ridged veins along the noise iso-lines.
    float vein = 1.0 - smoothstep(0.0, VEIN_WIDTH, abs(n - 0.5));
    vein *= cover;

    // Data blocks drift outward in a pixel grid, sparse and flickering.
    vec2 cell = floor(vec2(s, d - t * DATA_SPEED) / DATA_CELL);
    float on = step(1.0 - DATA_DENSITY, bf_hash(cell + vec2(3.0, 1.0)));
    float flick = step(0.35, bf_hash(cell + floor(t * 8.0)));
    vec2 inner = fract(vec2(s, d - t * DATA_SPEED) / DATA_CELL);
    float block = step(0.15, inner.x) * step(0.15, inner.y);
    float data = on * flick * block * cover * smoothstep(0.2, 0.6, n);

    return vec3(cover, max(vein, lash * (1.0 - cover * 0.6)), data);
}

vec4 border(vec2 uv) {
    float t = umbriel_time;
    bool pal = umbriel_palette_count > 0;
    vec3 c_main = COL_MAIN;
    vec3 c_black = COL_BLACK;
    vec3 c_deep = COL_DEEP;
    vec3 c_hot = COL_HOT;
    vec3 c_data = COL_DATA;
    if (pal) {
        c_main = umbriel_palette_at(0.0).rgb;
        c_black = c_main * BLACK_SHARE;
        c_deep = c_main * DEEP_SHARE;
        c_hot = mix(c_main, vec3(1.0), HOT_WHITE);
        c_data = mix(mix(c_main, c_hot, 0.4), umbriel_palette_at(0.25).rgb, DATA_ACCENT);
    }
    vec2 csize = umbriel_border_hole.zw * umbriel_size;
    vec2 p = (uv - umbriel_border_hole.xy) * umbriel_size;
    float d = umbriel_border_distance(uv);
    if (d < -2.0) return vec4(0.0);

    // Perimeter coordinate, continuous at three corners; the top-left seam is blended below.
    vec2 inset = vec2(max(-p.x, p.x - csize.x), max(-p.y, p.y - csize.y));
    float s;
    if (inset.y > inset.x) {
        s = p.y < 0.0 ? p.x : 2.0 * csize.x + csize.y - p.x;
    } else {
        s = p.x > csize.x ? csize.x + p.y : 2.0 * csize.x + 2.0 * csize.y - p.y;
    }
    float perim = 2.0 * (csize.x + csize.y);

    // Glitch tears: a band of the perimeter jumps sideways for a moment.
    float slot = floor(t / GLITCH_PERIOD);
    float phase = fract(t / GLITCH_PERIOD);
    float active = step(bf_hash(vec2(slot, 7.0)), GLITCH_CHANCE) * step(phase, 0.06);
    float band_c = bf_hash(vec2(slot, 11.0)) * perim;
    float band_w = 30.0 + 90.0 * bf_hash(vec2(slot, 13.0));
    float in_band = active * step(abs(s - band_c), band_w);
    s += in_band * GLITCH_PX * (bf_hash(vec2(slot, 17.0)) - 0.5) * 2.0;
    float dd = max(d, 0.0);

    vec3 f = bf_field(s, dd, t);
    // Blend across the top-left seam where s wraps from perim back to zero.
    float seam = smoothstep(perim - 60.0, perim, s);
    if (seam > 0.0) f = mix(f, bf_field(s - perim, dd, t), seam);

    float pulse = 0.75 + 0.25 * pow(0.5 + 0.5 * sin(6.2831853 * t / PULSE_PERIOD), 3.0);

    // Body: near-black flesh shading to deep crimson at the hot core.
    float core = exp(-dd / 9.0);
    vec3 col = mix(c_black, c_deep, 0.2 + 0.8 * core * pulse);
    col += c_main * f.y * VEIN_GAIN * (0.5 + 0.5 * pulse);
    col += c_data * f.z;

    // Searing edge line where the wall meets the window.
    float edge = exp(-abs(d - 0.5) / 1.2);
    col += mix(c_main, c_hot, 0.5 * pulse) * edge * 1.2;

    // Torn band: chromatic split and bright static.
    if (in_band > 0.0) {
        float stat = bf_hash(vec2(floor(s / 2.0), floor(dd / 2.0) + floor(t * 30.0)));
        col = mix(col * vec3(1.3, 0.5, 1.2), c_data, 0.35 * stat);
    }

    // Faint scanlines keep it digital.
    float scan = 0.85 + 0.15 * step(0.5, fract(dd / 2.0));
    col *= scan;

    // The wall body is near-opaque; veins and tendrils stay visible past its front.
    float alpha = clamp(max(f.x * 0.94, max(edge, f.y)), 0.0, 1.0);
    return vec4(col * alpha, alpha);
}
