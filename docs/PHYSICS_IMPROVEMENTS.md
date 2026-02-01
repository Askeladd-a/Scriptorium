# Miglioramenti Fisica Custom - Guida Completa

*Fonte: Mathematics of Game Development (Jacob Enfield), Basic Computer Coding Lua (Katya Podkovyroff)*

## Sommario Miglioramenti Implementati

### ✅ 1. Tensore d'Inerzia 3x3 (Momento d'Inerzia Accurato)
**File:** `stars.lua` - `star:set()`

**Problema precedente:** Usava `theta` scalare per inerzia rotazionale, inadeguato per corpi 3D.

**Soluzione:**
- Calcolo tensore inerzia 3x3 diagonale per ogni rigid body
- Formula: $I_{ii} = \sum_k m_k (r_k^2 - r_{k,i}^2)$ per ogni asse
- Componenti: `star.inertia = {Ixx, Iyy, Izz}` e `star.invInertia` (cache inverso)
- Mantiene `theta` per retrocompatibilità come media degli autovalori

**Fonte teoria:** Mathematics of Game Development, Cap. su Rigid Body Dynamics

**Parametri tuning:**
```lua
-- in main.lua, per ogni dado:
dice[i].star.mass = 1.2          -- massa del dado (kg virtuale)
-- L'inerzia è calcolata automaticamente dai vertici
```

### ✅ 2. SAT (Separating Axis Theorem) per Collisioni
**File:** `stars.lua` - `sat_collision()`, `obb_collision()`

**Problema precedente:** AABB semplice, imprecisa per corpi rotanti.

**Soluzione:**
- Broad-phase: AABB migliorata con bounding box pre-calcolata
- Narrow-phase: SAT sphere-sphere (approssimazione veloce)
- TODO futuro: OBB completo con 15 assi (3 facce A + 3 facce B + 9 edge-edge)
- Ritorna `{normal, penetration, contact}` per resolution

**Fonte teoria:** Mathematics of Game Development, Cap. su Collision Detection

**Parametri tuning:**
```lua
-- radius viene calcolato automaticamente in star:set()
-- Per debug: attiva physics_debug per vedere bounding boxes
```

### ✅ 3. Continuous Collision Detection (CCD)
**File:** `stars.lua` - `box:update()` swept-sphere

**Problema precedente:** Tunneling ad alte velocità.

**Soluzione:**
- Swept-sphere algorithm: traccia la sfera lungo il suo path di movimento
- Quadratic solve: $at^2 + bt + c = 0$ per time-of-impact
- Se TOI ∈ [0,1]: rewind a TOI, applica impulso, avanza resto step
- Fallback a discrete collision se CCD non trova hit

**Fonte teoria:** Mathematics of Game Development, Cap. su Advanced Collision

**Parametri tuning:**
```lua
-- CCD è automatico quando la velocità relativa è significativa
-- Nessun parametro esterno da tunare
```

### ✅ 4. Positional Correction (Baumgarte Stabilization)
**File:** `stars.lua` - `box:update()`

**Problema precedente:** Penetrazione accumulata causa sinking.

**Soluzione:**
- Slop tolerance: ignora penetrazioni < slop (evita jitter)
- Correction: `Δpos = normal * (penetration - slop) * percent / (invMassA + invMassB)`
- Applicata proporzionalmente alle masse inverse

**Fonte teoria:** Mathematics of Game Development, Cap. su Constraint Resolution

**Parametri tuning:**
```lua
box.pos_slop = 0.01      -- penetrazione ignorata (units)
box.pos_percent = 0.2    -- forza correzione (0-1, più alto = più rigido ma instabile)
```

### ✅ 5. Coulomb Friction nei Contatti
**File:** `stars.lua` - `box:update()` tangential impulse

**Problema precedente:** Solo restitution, nessuna friction.

**Soluzione:**
- Decomposizione velocità: normale + tangenziale
- Impulso friction: $J_t = \min(|-v_t / denom|, \mu |J_n|)$
- Coulomb cone: friction limitata a `μ * normal_impulse`
- Coefficiente `μ` medio tra i due corpi

**Fonte teoria:** Mathematics of Game Development, Cap. su Contact Friction

**Parametri tuning:**
```lua
-- Per ogni star:
dice[i].star.friction = 0.75      -- coefficiente friction (0-1)
dice[i].star.restitution = 0.25   -- coefficiente rimbalzo (0-1)

-- Materiali preset in materials.lua
```

### ✅ 6. Fixed Timestep con Sub-stepping
**File:** `stars.lua` - `box:update(dt)`

**Problema precedente:** Timestep variabile causa instabilità.

**Soluzione:**
- Accumulator pattern: `timeleft += dt`
- Loop: `while timeleft > box.dt do ... timeleft -= box.dt`
- Max steps clamp per spiral-of-death
- Interpola rendering tra steps (TODO)

**Fonte teoria:** Fix Your Timestep (Gaffer on Games)

**Parametri tuning:**
```lua
box.dt = 1/60               -- timestep fisso (secondi)
box.max_steps = 5           -- max substeps per frame (clamp spiral-of-death)
```

### ✅ 7. Global & Per-Body Damping
**File:** `stars.lua` - `box:update()`, `star:push()`

**Problema precedente:** Oscillazioni infinite, jitter visibile.

**Soluzione:**
- Linear damping: `velocity *= (1 - damping * dt)`
- Angular damping: `angular *= (1 - damping * dt)`
- Per-body override possibile: `star.linear_damping`
- Velocity clamps per sicurezza

**Parametri tuning:**
```lua
-- Globali (in box):
box.linear_damping = 0.18    -- damping velocità lineare (0-1)
box.angular_damping = 0.18   -- damping velocità angolare (0-1)

-- Per-body override (in main.lua):
dice[i].star.linear_damping = 0.06
dice[i].star.angular_damping = 0.08
```

### ✅ 8. Sleep Detection
**File:** `stars.lua` - `box:update()`

**Problema precedente:** CPU sprecata su corpi quasi fermi.

**Soluzione:**
- Threshold: corpo dorme se `|v| < sleep_linear` e `|ω| < sleep_angular`
- Timer: deve rimanere sotto threshold per `sleep_time` secondi
- Wake on collision o external impulse
- Skip physics update quando `star.asleep == true`

**Parametri tuning:**
```lua
box.sleep_linear = 0.05      -- soglia velocità lineare (units/s)
box.sleep_angular = 0.2      -- soglia velocità angolare (rad/s)
box.sleep_time = 0.5         -- tempo sotto threshold per dormire (s)
```

### ✅ 9. Physics Debug Visualizer
**File:** `physics_debug.lua`

**Features:**
- Velocità lineari (vettori verdi)
- Velocità angolari (cerchi arancioni)
- Bounding boxes (box gialli)
- Contatti storici (punti rossi + normali gialle)
- Sleep state (cerchi blu + label)
- HUD con statistiche real-time

**Utilizzo:**
```lua
-- In love.draw():
physics_debug.draw_all(box)

-- Key bindings (in main.lua):
-- D: toggle debug on/off
-- V: toggle velocities
-- C: toggle contacts
-- B: toggle bounding boxes
```

### ✅ 10. Automated Test Suite
**File:** `physics_tests.lua`

**Tests implementati:**
1. **Linear Momentum Conservation:** collisione elastica conserva momento
2. **Energy Conservation:** corpo in moto libero conserva energia
3. **Numerical Stability:** 1000 steps senza NaN/Inf/explosion
4. **Sleep Detection:** corpo fermo va a sleep dopo threshold
5. **Reproducibility:** stesso seed → stessa simulazione

**Utilizzo:**
```lua
-- In love.load() o console Lua:
physics_tests = require("physics_tests")
physics_tests.set_seed(12345)  -- seed riproducibile
physics_tests.run_all()        -- esegue tutti i test
physics_tests.save_report("report.txt")  -- salva risultati
```

---

## Parametri da Tunare (Priority Order)

### 🔥 Alta Priorità (impatto gameplay)

#### 1. Materiali Fisici
```lua
-- main.lua, per ogni dado:
dice[i].star.mass = 1.2              -- più pesante = più difficile spostare
dice[i].star.restitution = 0.25      -- 0=stick, 1=bounce perfetto
dice[i].star.friction = 0.75         -- 0=ice, 1=velcro
```

**Preset suggeriti:**
- **Legno:** mass=1.2, restitution=0.25, friction=0.75
- **Metallo:** mass=2.5, restitution=0.35, friction=0.3
- **Plastica:** mass=0.8, restitution=0.45, friction=0.5
- **Gomma:** mass=1.0, restitution=0.15, friction=0.95

#### 2. Damping Globale
```lua
-- stars.lua, box:set() o override in main.lua:
box.linear_damping = 0.18     -- ↑ = si fermano prima (più viscoso)
box.angular_damping = 0.18    -- ↑ = smettono di girare prima
```

**Suggerimenti:**
- **Tavolo liscio:** linear=0.05, angular=0.05
- **Tavolo feltro:** linear=0.18, angular=0.18 (default)
- **Sabbia:** linear=0.50, angular=0.50

#### 3. Gravity
```lua
-- main.lua, box:set():
box:set(10, 10, 10, vector{0, 0, -9.8}, ...)
                         -- ^^^^^^^^^ gravità (m/s²)
```

**Suggerimenti:**
- **Realistico:** -9.8 (Terra)
- **Drammatico:** -15.0 (più veloce)
- **Slow-motion:** -5.0

### ⚙️ Media Priorità (stabilità)

#### 4. Positional Correction
```lua
box.pos_slop = 0.01        -- ↑ = tolera più penetrazione (meno jitter)
box.pos_percent = 0.2      -- ↑ = correzione più forte (più rigido, rischio instabilità)
```

**Troubleshooting:**
- **Jitter visibile:** aumenta `pos_slop` a 0.02-0.03
- **Dadi si compenetrano:** aumenta `pos_percent` a 0.3-0.4 (cautela!)

#### 5. Sleep Thresholds
```lua
box.sleep_linear = 0.05    -- ↓ = dorme prima (più aggressivo)
box.sleep_angular = 0.2    -- ↓ = dorme prima
box.sleep_time = 0.5       -- ↓ = dorme prima
```

**Suggerimenti:**
- **Preciso (finecorsa perfetto):** linear=0.02, angular=0.1, time=1.0
- **Fast (performance):** linear=0.10, angular=0.3, time=0.3

#### 6. Collision Safety Clamps
```lua
box.dv_max = 50             -- max Δvelocity da impulso (evita esplosioni)
box.angular_max = 25        -- max velocità angolare (rad/s)
```

**Troubleshooting:**
- **Dadi "esplodono":** riduci `dv_max` a 20-30
- **Collisioni weird:** controlla che mass > 0 per tutti

### 🔬 Bassa Priorità (ottimizzazione)

#### 7. Fixed Timestep
```lua
box.dt = 1/60               -- ↓ = più preciso ma più CPU
box.max_steps = 5           -- max substeps per frame
```

**Suggerimenti:**
- **Preciso:** dt=1/120, max_steps=10
- **Performance:** dt=1/60, max_steps=3 (default OK)

#### 8. Broad-phase (sweep & prune)
- Già ottimizzato con sorting su X
- Se >20 dadi: considera spatial hashing (TODO)

---

## Workflow di Tuning Raccomandato

### Step 1: Baseline (usa defaults)
```lua
-- Usa i valori di default e testa:
physics_tests.run_all()  -- devono passare tutti
```

### Step 2: Materiali
1. Scegli preset materiale (legno/metallo/plastica)
2. Applica a tutti i dadi
3. Test lancio: devono sembrare "reali"
4. Tweak friction/restitution se troppo slide/bounce

### Step 3: Damping
1. Lancia dadi e conta quanto tempo girano
2. Se >5 secondi: aumenta damping
3. Se <2 secondi: riduci damping
4. Target: 2-4 secondi per fermarsi

### Step 4: Sleep
1. Attiva physics_debug (tasto D)
2. Verifica che dadi vadano a sleep dopo 0.5-1.0s di quiete
3. Se jitter: aumenta sleep thresholds
4. Se CPU alta: riduci sleep_time

### Step 5: Stabilità
1. Lancia 10 dadi contemporaneamente
2. Controlla physics_debug per NaN/explosion
3. Se instabile: riduci pos_percent, aumenta pos_slop
4. Se penetrazione: aumenta pos_percent (cautela)

### Step 6: Profiling
```lua
-- In love.update(), aggiungi timing:
local t0 = love.timer.getTime()
box:update(dt)
local physics_time = love.timer.getTime() - t0
-- Target: <2ms per frame (60fps), <8ms per frame (120fps)
```

---

## Troubleshooting Comune

### Problema: Dadi rimbalzano troppo
**Causa:** `restitution` troppo alta  
**Fix:** Riduci a 0.2-0.3

### Problema: Dadi "scivolano" troppo
**Causa:** `friction` troppo bassa  
**Fix:** Aumenta a 0.6-0.8

### Problema: Dadi si compenetrano
**Causa:** `pos_percent` troppo basso o timestep troppo grande  
**Fix:** Aumenta `pos_percent` a 0.3-0.4 o riduci `dt`

### Problema: Jitter visibile quando fermi
**Causa:** `pos_slop` troppo basso o `sleep_time` troppo alto  
**Fix:** Aumenta `pos_slop` a 0.02 e riduci `sleep_time` a 0.3

### Problema: Dadi "esplodono" o velocità folle
**Causa:** Impulso troppo grande o mass=0  
**Fix:** Controlla `box.dv_max=50` e verifica `mass > 0`

### Problema: CPU alta anche con pochi dadi
**Causa:** Sleep detection non funziona  
**Fix:** Riduci `sleep_linear/angular` e `sleep_time`

### Problema: Simulazione non riproducibile
**Causa:** Seed random non impostato  
**Fix:** `math.randomseed(seed)` in love.load()

---

## Testing & Validation

### Test Manuali
1. **Drop test:** lancia 1 dado da 5 unità, deve fermarsi in ~2-3s
2. **Collision test:** lancia 2 dadi contrapposti, devono rimbalzare e fermarsi
3. **Stack test:** impila 3 dadi, non devono penetrare o jitter
4. **Edge test:** dado su bordo tavolo, non deve tunnel through

### Test Automatizzati
```bash
# Esegui suite completa
lua -e "require('physics_tests').run_all()"

# Oppure in LÖVE console:
physics_tests.run_all()
physics_tests.save_report()
```

### Debug Visivo
1. Attiva physics_debug (D)
2. Controlla velocità (V): vettori verdi proporzionali
3. Controlla contatti (C): punti rossi ai contatti
4. Controlla bboxes (B): box gialli non si sovrappongono
5. Sleep state: cerchi blu quando dormiente

---

## Next Steps (TODO)

### Miglioramenti Futuri
1. **OBB completo:** implementa SAT con 15 assi per precision collision
2. **Friction anisotropica:** diversa per assi (urti vs rotolamento)
3. **Warm starting:** cache impulsi per convergenza più veloce
4. **Contact manifolds:** multi-point contacts per stabilità
5. **Spatial hashing:** broad-phase più efficiente per >20 dadi
6. **Rendered interpolation:** smooth visuals tra substeps

### Performance Optimization
1. **SIMD math:** usa FFI/LuaJIT per vector ops
2. **Object pooling:** riusa star objects invece di clone
3. **Lazy bbox update:** ricalcola solo se rotazione significativa
4. **Adaptive substeps:** più steps solo durante collisioni

---

## References

**Manuali consultati:**
- *Mathematics of Game Development* (Jacob Enfield, 2024): rigid body dynamics, collision detection, SAT, impulse resolution
- *Basic Computer Coding Lua* (Katya Podkovyroff, 2024): Lua patterns, tables, performance

**Risorse esterne:**
- Fix Your Timestep (Glenn Fiedler)
- Box2D Manual (Erin Catto)
- Game Physics Engine Development (Ian Millington)

**Code conventions:**
- Vettori: `vector{x,y,z}` da `vector.lua`
- Stars: rigid bodies, lista di punti + stato
- Box: simulatore, contiene N stars
- Materials: preset fisici in `materials.lua`

---

**Ultimo aggiornamento:** 2026-02-01  
**Versione fisica:** v2.0 (inerzia 3x3, CCD, friction, tests)
