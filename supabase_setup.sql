-- ============================================================
-- Power Forward Fitness Tracker — Supabase Database Setup
-- Run this entire script in Supabase → SQL Editor → New query
-- ============================================================

-- ── 1. PROFILES ──────────────────────────────────────────────
-- One row per user, extends Supabase's built-in auth.users table
create table if not exists profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  display_name text not null,
  role text not null default 'member', -- 'admin' or 'member'
  created_at timestamptz default now()
);

-- Allow users to read and update their own profile
alter table profiles enable row level security;

create policy "Users can view own profile"
  on profiles for select using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);

-- Admin can view all profiles
create policy "Admin can view all profiles"
  on profiles for select using (
    exists (
      select 1 from profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- Auto-create a profile row when a new user signs up
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'member')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();


-- ── 2. EXERCISE LIBRARY ──────────────────────────────────────
-- Shared across all users; only admin can edit
create table if not exists exercises (
  id uuid default gen_random_uuid() primary key,
  category text not null, -- 'Warm-Up' | 'Core' | 'Lower Body' | 'Upper Push' | 'Upper Pull' | 'Cool-Down'
  name text not null,
  sets text,
  reps text,
  notes text,
  active boolean default true,
  sort_order integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table exercises enable row level security;

-- Everyone can read exercises
create policy "All users can view exercises"
  on exercises for select using (auth.role() = 'authenticated');

-- Only admin can insert / update / delete
create policy "Admin can manage exercises"
  on exercises for all using (
    exists (
      select 1 from profiles
      where id = auth.uid() and role = 'admin'
    )
  );


-- ── 3. PLANNER OVERRIDES ─────────────────────────────────────
-- Per-user day overrides (swap workout type for a specific date)
create table if not exists planner_overrides (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  workout_type text not null,
  created_at timestamptz default now(),
  unique(user_id, date)
);

alter table planner_overrides enable row level security;

create policy "Users manage own overrides"
  on planner_overrides for all using (auth.uid() = user_id);


-- ── 4. COMPLETED WORKOUTS ────────────────────────────────────
create table if not exists completed_workouts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  workout_type text not null,
  completed_at timestamptz default now(),
  unique(user_id, date)
);

alter table completed_workouts enable row level security;

create policy "Users manage own completions"
  on completed_workouts for all using (auth.uid() = user_id);


-- ── 5. SESSION LOGS ──────────────────────────────────────────
create table if not exists session_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

alter table session_logs enable row level security;

create policy "Users manage own logs"
  on session_logs for all using (auth.uid() = user_id);


-- ── 6. GOLF ROUNDS ───────────────────────────────────────────
create table if not exists golf_rounds (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  course text not null,
  played_on date default current_date,
  created_at timestamptz default now()
);

alter table golf_rounds enable row level security;

create policy "Users manage own golf rounds"
  on golf_rounds for all using (auth.uid() = user_id);


-- ── 7. SEED EXERCISE LIBRARY ─────────────────────────────────
-- Your trainer's exercises, all active = true
-- Generic defaults kept as active = false

insert into exercises (category, name, sets, reps, notes, active, sort_order) values

-- WARM-UP (trainer)
('Warm-Up','Bike warm-up','','10 minutes','Nasal breathing only; toes up; straight spine; activated face',true,10),
('Warm-Up','High child''s pose with arm walks','','15 sec center / 15 sec each side','Walk hands right then left; hold each position',true,20),
('Warm-Up','Pigeon stretch','','30 sec each side','Keep spine tall; slow nasal breathing',true,30),
('Warm-Up','Middle split stretch on knees','','30 sec','Press knees gently outward',true,40),
('Warm-Up','Dynamic superman','','30 sec','Arms overhead; controlled lift and lower',true,50),
('Warm-Up','Side rib stretch (left then right)','','30 sec each side','Reach arm overhead; keep hips level',true,60),
('Warm-Up','Cobra stretch','','30 sec','Press through palms; open chest; keep glutes relaxed',true,70),
('Warm-Up','Bent knee plank','','30 sec','Knees down; neutral spine; breathe steadily',true,80),
('Warm-Up','Quadruped rock backs','2','15 each side','On hands and knees; sit back toward heels; maintain neutral spine',true,90),
('Warm-Up','Dead bug','2','10 each side','Lower back pressed to floor throughout; move slowly',true,100),
('Warm-Up','Standing heel lifts with toes up','','30 sec','Toes lifted; slow controlled rises; activates arch and calf',true,110),
('Warm-Up','Standing toe raises','','30 sec','Lift toes while heels stay planted; activates shin and foot',true,120),
('Warm-Up','PVC overhead squat','','10 reps','Arms straight overhead; palms forward; heels down; toes up; mouth closed; activated face',true,130),
('Warm-Up','PVC Romanian deadlift','','10 reps (5 front / 5 behind)','5 reps pipe vertical in front; 5 reps pipe behind head above shoulder blades; 3 contact points',true,140),
('Warm-Up','PVC forward lunge','','5 each leg','Pipe overhead; step forward; front knee over ankle',true,150),
('Warm-Up','PVC reverse lunge','','5 each leg','Pipe overhead; step back; tall posture throughout',true,160),
('Warm-Up','PVC lateral lunge','','5 each side','Pipe overhead; push hips back to the side; keep planted foot flat',true,170),
-- WARM-UP (generic, inactive)
('Warm-Up','Hip circles','','10 each side','Stand feet shoulder-width; slow controlled circles',false,500),
('Warm-Up','Arm circles','','10 fwd / 10 back','Full range; start small and increase',false,510),
('Warm-Up','Bodyweight squats','','10 reps','Slow descent; chest up; knees track toes',false,520),
('Warm-Up','Side-to-side lunges','','8 each side','Keep back flat; press through heel to return',false,530),
('Warm-Up','Glute bridge march','','10 reps','Bridge position; alternate lifting knees',false,540),
('Warm-Up','Torso rotations','','10 each side','Arms crossed; feet planted; rotate from thoracic',false,550),
('Warm-Up','Leg swings (front/back)','','10 each leg','Hold wall for balance; keep core engaged',false,560),

-- CORE (trainer)
('Core','Hanging knee raises','2','15','Full hang; controlled lift; avoid swinging',true,10),
('Core','Bosu weighted crunch','2','20','Place small of back on Bosu dome; hold weight at chest',true,20),
('Core','Bosu superman','2','20','Prone on Bosu dome; extend arms and legs simultaneously',true,30),
('Core','Physio ball pike or rollout','2','15','Pike: feet on ball, hips up. Rollout: forearms on ball, roll out and back.',true,40),
('Core','Seated double leg raise with plate twist','2','30 sec each side','Legs extended; hold plate; rotate torso side to side while holding legs up',true,50),
('Core','Glute bridge with thigh squeeze','2','15','Loop band or place ball between knees; squeeze throughout the bridge',true,60),
('Core','Bench leg lift with medball between knees','3','30 sec','Hands gripping bench behind head; squeeze ball; lift legs to 90°',true,70),
('Core','Straight bar rollouts','3','30 sec','Kneel; roll bar forward keeping hips extended; pull back with lats',true,80),
('Core','Med ball pike-ups','3','30 sec','Feet on med ball in push-up position; pike hips to ceiling',true,90),
('Core','Superman with light dumbbells','3','30 sec','Prone; hold light DBs overhead; lift chest and legs simultaneously',true,100),
('Core','DB sit-up to stand','3','30 sec','Feet anchored under DBs; sit up and stand fully; reverse to start',true,110),
('Core','Seated double leg lift with OH plate hold','2-3','30 sec','Seated on bench; hold plate overhead; legs straight; lift and hold',true,120),
('Core','Standing leg lifts with OH hold','2-3','30 sec','Hold weight overhead; alternate leg lifts; keep core braced',true,130),
('Core','Bench side double leg lifts','2-3','30 sec','Side-lying on bench; both legs together; lift and lower with control',true,140),
('Core','DB crunch rotation','2-3','30 sec','Hold DB at chest; crunch and rotate right, then left',true,150),
('Core','PB belly double leg lift','2-3','10-12','Prone on physio ball; hands on floor; lift both legs behind you',true,160),
('Core','Towel side rollouts (hardwood)','2-3','10-12','Towels under hands on hardwood; slide arms out to sides; pull back in',true,170),
-- CORE (generic, inactive)
('Core','Plank hold','3','30-45 seconds','Neutral spine; breathe steadily',false,500),
('Core','Bird dog','3','10 each side','Extend opposite arm/leg; avoid hip rotation',false,510),
('Core','Side plank','2','20-30 sec each side','Stack feet or stagger for modification',false,520),
('Core','Pallof press','3','10 each side','Cable or band at chest; resist rotation',false,530),
('Core','Hollow body hold','3','20 seconds','Lower back glued to floor; arms overhead',false,540),

-- LOWER BODY (trainer)
('Lower Body','Thigh band lateral walk + SPRI band overhead hold','2','15 steps each direction','Mini band above knees; hold SPRI band overhead; maintain squat position',true,10),
('Lower Body','Dumbbell squat to press','3','8-12','Squat with DBs at shoulders; press overhead as you stand; controlled descent',true,20),
('Lower Body','Squat hops','3','15','Immediately after each squat set; toes up in air; soft quiet landings into hip load',true,30),
('Lower Body','RDL straight bar','3','10','Hip hinge; bar close to legs; feel hamstrings load; maintain 3 spine contact points',true,40),
('Lower Body','Single-leg RDL with alternating DB row','3','6 each leg','Balance on one leg; hinge and row opposite DB; slow and controlled',true,50),
('Lower Body','DB split squat (rear foot elevated)','3','8','Back foot on bench; front foot forward; drop straight down; drive through front heel',true,60),
('Lower Body','BW reverse lunge with SPRI band overhead','3','10 each leg','Hold band overhead; step back; keep torso upright',true,70),
('Lower Body','Dumbbell lateral step-ups','3','10 each leg','Step up to side; drive through heel; fully extend hip at top',true,80),
('Lower Body','BW lateral lunge with leg elevated + SPRI band overhead','3','10 each side','Rear leg elevated; band overhead; push hips back on lateral lunge',true,90),
('Lower Body','DB calf raises on step','3','15','Full range of motion; pause at top; control the descent',true,100),
('Lower Body','Jump rope','','40 sec','Between lower body sets; light on feet; nasal breathing if possible',true,110),
-- LOWER BODY (generic, inactive)
('Lower Body','Goblet squat','3','12 reps','Dumbbell at chest; elbows inside knees',false,500),
('Lower Body','Reverse lunge','3','10 each leg','Step back; front knee over ankle; drive through heel',false,510),
('Lower Body','Lateral band walk','3','12 each direction','Mini band above knees; maintain squat position',false,520),
('Lower Body','Sumo squat','3','12 reps','Wide stance; toes out; weight in heels',false,530),
('Lower Body','Hip thrust','3','12 reps','Shoulders on bench; drive hips up; squeeze glutes',false,540),
('Lower Body','Leg press','3','12 reps','Feet hip-width; don''t lock knees at top',false,550),

-- UPPER PUSH (trainer)
('Upper Push','Standing DB push press','2-3','10','Dip slightly then drive the DBs overhead; lock out at top',true,10),
('Upper Push','Seated DB chest fly','2-3','10-12','Try settings 2 and 3 on adjustable bench; slight bend in elbows; squeeze at top',true,20),
('Upper Push','Standing DB overhead press','2-3','10-12','Neutral or pronated grip; avoid arching lower back; brace core',true,30),
('Upper Push','DB incline bench press','2-3','10-12','Adjustable bench at setting 2 or 3; control the descent; elbows at 45°',true,40),
('Upper Push','DB flat bench press','2-3','10-12','Feet flat on floor; full range; lower to mid-chest',true,50),
('Upper Push','Seated incline bench press (Smith)','2-3','10-12','Settings 2 and 3; Smith machine for stability; control both directions',true,60),
('Upper Push','Flat bench press','2-3','10-12','Barbell or Smith; full ROM; keep shoulder blades retracted',true,70),
('Upper Push','Standing DB lateral raise','2-3','12-15','Slight bend in elbow; lead with elbows; avoid shrugging',true,80),
('Upper Push','Triceps pressdown straight bar','2-3','12-15','Cable; elbows pinned to sides; full extension at bottom',true,90),
('Upper Push','SPRI band chest opener above head','2-3','30 sec','Band overhead; pull apart; open chest; slow nasal breathing',true,100),
('Upper Push','SPRI band chest opener across chest','2-3','30 sec','Band at chest height; pull apart; squeeze shoulder blades',true,110),
-- UPPER PUSH (generic, inactive)
('Upper Push','Arnold press','3','10 reps','Rotate palms during press; full range',false,500),
('Upper Push','Push-up','3','10-15 reps','Hands shoulder-width; body in straight line',false,510),

-- UPPER PULL (trainer)
('Upper Pull','Band-assisted chin-ups','2-3','10 max full ROM','Full range of motion; controlled descent; use band for assistance as needed',true,10),
('Upper Pull','Standing lat pulldown','2-3','10-12','Cable; stand facing machine; pull bar to upper chest; slight lean back',true,20),
('Upper Pull','Standing pulldown palms up','2-3','10-12','Underhand grip; engage biceps and lats together; full extension at top',true,30),
('Upper Pull','DB or straight bar bent-over rows','2-3','10-12','Hinge to 45°; pull to lower ribs; squeeze shoulder blades at top',true,40),
('Upper Pull','Inverted row (bodyweight or legs elevated)','2-3','10-12','Bar at waist height; body straight; pull chest to bar; harder with legs elevated',true,50),
('Upper Pull','DB reverse flyes','2-3','10-12','Hinge forward; slight bend in elbows; lead with elbows; squeeze rear delts',true,60),
('Upper Pull','DB glute bridge','2-3','10-12','DB on hips; drive hips to ceiling; squeeze glutes at top; lower with control',true,70),
('Upper Pull','DB shrugs','2-3','10-12','Straight arms; shrug to ears; hold 1 sec at top; avoid rolling shoulders',true,80),
('Upper Pull','DB bicep curls','2-3','10-12','Control the descent; don''t swing; full range of motion',true,90),
-- UPPER PULL (generic, inactive)
('Upper Pull','Face pull','3','15 reps','Cable at eye level; pull to forehead; externally rotate',false,500),
('Upper Pull','Hammer curl','3','12 reps','Neutral grip; control both directions',false,510),
('Upper Pull','TRX / ring row','3','10 reps','Body in straight line; pull chest to handles',false,520),
('Upper Pull','Lat pulldown','3','10 reps','Wide grip; pull to upper chest; avoid swinging',false,530),
('Upper Pull','Single-arm dumbbell row','3','10 each side','Brace on bench; elbow close to body',false,540),
('Upper Pull','Rear delt fly','3','12 reps','Hinge forward; arms out to sides; squeeze',false,550),

-- COOL-DOWN (trainer)
('Cool-Down','Child''s pose','','30 seconds','Arms extended; sink hips to heels; slow nasal breathing',true,10),
('Cool-Down','Doorway chest stretch','','30 sec each side','Arm at 90°; lean gently into doorway; open chest',true,20),
('Cool-Down','Overhead lat stretch','','30 sec each side','Band or doorframe; arm overhead; lean away; feel lat stretch',true,30),
('Cool-Down','Cobra stretch','','30 seconds','Press through palms; open chest; keep glutes relaxed',true,40),
('Cool-Down','Side rib stretch','','30 sec each side','Reach arm overhead; lean to opposite side; breathe into the stretch',true,50),
('Cool-Down','Deep nasal breathing','','1 minute','Seated or lying; expand ribs and abdomen with every breath; mouth closed',true,60),
('Cool-Down','Pigeon pose (supported by block if needed)','','60 sec each side','Block under hip if needed; spine tall; slow nasal breathing',true,70),
('Cool-Down','Kneeling hip flexor stretch','2','45 sec each side','Half-kneeling; squeeze glute of back leg; reach same-side arm overhead',true,80),
('Cool-Down','Seated hamstring stretch','','60 seconds','Heels on physio ball; legs straight and externally rotated; pull toes toward shins',true,90),
('Cool-Down','Supported deep squat hold','2','30-60 seconds','Press knees out with elbows; toes up; heels planted; nasal breathing; chest high',true,100),
('Cool-Down','Spinal decompression stretch','','30-60 seconds','Hang from bar or drape over ball; decompress spine; breathe slowly',true,110),
('Cool-Down','Physio ball thoracic extension','2','30-60 seconds','Lean upper back over ball; support head; open chest to ceiling',true,120),
('Cool-Down','Physio ball prayer pose','','5-10 breaths','Kneel in front of ball; hands on top; roll forward; drop chest toward floor',true,130),
('Cool-Down','Physio ball side lat stretch','','5 breaths each side','Forearms on ball; roll slightly to one side; feel stretch along opposite lat',true,140),
('Cool-Down','PVC overhead side bend','','5 each side / 3 breaths','PVC overhead with straight arms; keep hips level; bend slowly to each side',true,150),
('Cool-Down','PVC thoracic rotation','','10 each side / 2 sec hold','PVC across shoulders; feet shoulder-width; rotate from upper back; keep hips still',true,160),
('Cool-Down','Band hamstring stretch','2','60 sec each side','Lie on back; loop band around foot; straighten leg to ceiling; keep other leg flat',true,170),
('Cool-Down','Band hamstring stretch with spinal twist','2','2x each side','Same as band hamstring; guide leg across body; keep opposite arm flat on floor',true,180),
('Cool-Down','Band chest opener','2','30-45 seconds','Band behind back; straight elbows; lift arms away from body; open chest',true,190),
('Cool-Down','Standing quad stretch with bar or band','','30 sec each side','Foot behind; dorsally flexed; hold bar for balance; keep knees together',true,200),
('Cool-Down','PVC half-kneeling psoas stretch','2','30 sec each side','Half-kneeling; PVC overhead; squeeze back glute; tall posture',true,210),
('Cool-Down','PVC half-kneeling psoas stretch with twist','2','30 sec each side','Same as above; add thoracic rotation toward front leg',true,220),
('Cool-Down','Yoga block prayer pose','','right to left','Block under hands; prayer position; shift right and left; hold each side',true,230),
('Cool-Down','Yoga block down dog','','5-10 breaths','Hands on block; press hips to ceiling; pedal heels gently',true,240),
('Cool-Down','Yoga block cobra','','30 seconds','Block under hands; press up; open chest; relaxed glutes',true,250),
('Cool-Down','Band overhead lat stretch with hip lift','2','30-60 sec','Band overhead; pull apart; stretch each side with heel lift; ribs down',true,260),
-- COOL-DOWN (generic, inactive)
('Cool-Down','Figure-4 hip stretch','','30 sec each','Seated or lying; cross ankle over knee',false,500),
('Cool-Down','Cross-body shoulder stretch','','20 sec each','Pull arm across chest at shoulder height',false,510),
('Cool-Down','Supine spinal twist','','30 sec each side','Lying down; guide knee across body',false,520),
('Cool-Down','Neck rolls','','5 each direction','Slow; do not roll head backward',false,530),
('Cool-Down','Standing quad stretch','','30 sec each','Hold ankle; keep knees together',false,540);

-- Done!
select 'Setup complete. Tables created and exercises seeded.' as status;
