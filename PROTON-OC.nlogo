__includes ["nls_files/experiments.nls"]

extensions [nw table csv profiler rnd]

breed [jobs      job]
breed [employers employer]
breed [schools   school]
breed [persons   person]
breed [prisoners prisoner]

undirected-link-breed [household-links    household-link]    ; person <--> person
undirected-link-breed [partner-links      partner-link]      ; person <--> person
undirected-link-breed [sibling-links      sibling-link]      ; person <--> person
directed-link-breed   [offspring-links    offspring-link]    ; person <--> person
undirected-link-breed [friendship-links   friendship-link]   ; person <--> person
undirected-link-breed [criminal-links     criminal-link]     ; person <--> person
undirected-link-breed [professional-links professional-link] ; person <--> person
undirected-link-breed [school-links       school-link]       ; person <--> person
undirected-link-breed [meta-links         meta-link]         ; person <--> person

persons-own [
  num-crimes-committed
  num-crimes-committed-this-tick
  education-level        ; level: last school I finished (for example, 4: I finished university)
  max-education-level
  wealth-level
  job-level
  my-job                 ; 0 for inactive, 1 for unemployed. Could be known from `one-of job-link-neighbors`, but is stored directly for performance - need to be kept in sync
  birth-tick
  male?
  propensity
  oc-member?
  cached-oc-embeddedness ; only calculated (if needed) when the `oc-embeddedness` reporter is called
  partner                ; the person's significant other
  retired?
  number-of-children
  facilitator?
  hobby
  new-recruit
  migrant?
  age
  criminal-tendency
  my-school
  target-of-intervention
  arrest-weight
  ; WARNING: If you add any variable here, it needs to be added to `prisoners-own` as well!
]

prisoners-own [
  sentence-countdown
  num-crimes-committed
  num-crimes-committed-this-tick
  education-level     ; level: last school I finished (for example, 4: I finished university)
  max-education-level
  wealth-level
  job-level
  my-job               ; could be known from `one-of job-link-neighbors`, but is stored directly for performance - need to be kept in sync
  birth-tick
  male?
  propensity
  oc-member?
  cached-oc-embeddedness
  oc-embeddedness-fresh?
  partner                ; the person's significant other
  retired?
  number-of-children
  facilitator?
  hobby
  new-recruit
  migrant?
  age
  criminal-tendency
  my-school
  target-of-intervention
  arrest-weight
]

jobs-own [
  job-level
  my-employer
  my-worker
]

employers-own [
  my-jobs
]

schools-own [
  diploma-level ; finishing this school provides the level here
  my-students
]

criminal-links-own [
  num-co-offenses
  co-off-flag
]

meta-links-own [
  dist ; the "distance cost" of traversing that link
       ; (the stronger the link, the smaller the distance cost)
]

globals [
  ; operation
  initial-random-seed
  network-saving-interval      ; every how many we save networks structure
  network-saving-list          ; the networks that should be saved
  model-saving-interval        ; every how many we save model structure
  breed-colors           ; a table from breeds to turtle colors
  this-is-a-big-crime good-guy-threshold big-crime-from-small-fish ; checking anomalous crimes
  ; statistics tables
  num-co-offenders-dist  ; a list of probability for different crime sizes
  fertility-table        ; a list of fertility rates
  mortality-table
  edu_by_wealth_lvl
  work_status_by_edu_lvl
  wealth_quintile_by_work_status
  criminal_propensity_by_wealth_quintile
  edu
  punishment-length-list
  male-punishment-length-list
  female-punishment-length-list
  arrest-rate
  jobs_by_company_size
  education-levels  ; table from education level to data
  c-by-age-and-sex
  c-range-by-age-and-sex
  labour-status-by-age-and-sex
  labour-status-range
  ; outputs
  number-deceased
  facilitator-fails
  facilitator-crimes
  crime-size-fails
  number-born
  number-migrants
  number-weddings
  number-weddings-mean
  number-weddings-sd
  removed-fatherships
  criminal-tendency-addme-for-weighted-extraction
  criminal-tendency-subtractfromme-for-inverse-weighted-extraction
  number-law-interventions-this-tick
  correction-for-non-facilitators
  number-protected-recruited-this-tick
  number-offspring-recruited-this-tick
  co-offender-group-histo
  people-jailed
  number-crimes
  crime-multiplier
  kids-intervention-counter
  recruited
  dead-oc
  network-names network-used ; number of times a specific network is used for recruiting. All links existing are increased.
]

to profile-setup
  profiler:reset         ; clear the data
  profiler:start         ; start profiling
  setup                  ; set up the model
  profiler:stop          ; stop profiling
  print profiler:report  ; view the results
  profiler:reset         ; clear the data
  show timer
end

to profile-go
  set num-persons 1000
  profiler:reset         ; clear the data
  profiler:start         ; start profiling
  random-seed 12
  setup                  ; set up the model
  repeat 40 [ go show ticks]
  profiler:stop          ; stop profiling
  print profiler:report  ; view the results
  profiler:reset         ; clear the data
  show timer
end

to fix-unemployment [ correction ]
  let unemployed persons with [ job-level = 1 and age > 16 and age < 65 and my-school = nobody ]
  let occupied   persons with [ job-level > 1 and age > 16 and age < 65 and my-school = nobody ]
  let notlooking persons with [ job-level = 0 and age > 16 and age < 65 and my-school = nobody ]
  let ratio-on count occupied / (count occupied + count notlooking)
  ifelse correction > 1.0 [
    ; increase unemployment
    ask n-of ((correction - 1) * count unemployed * ratio-on) occupied [
      set job-level 1 ; no need to resciss job links as they haven't been created yet.
    ]
    ask n-of ((correction - 1) * count unemployed * (1 - ratio-on)) notlooking [
      set job-level 1
    ]
  ] [
    ; decrease unemployment
    ask n-of ((1 - correction) * count unemployed) unemployed [
      set job-level ifelse-value (random-float 1 < ratio-on) [ 2 ] [ 0 ]
    ]
  ]
end

to setup
  clear-all
  choose-intervention-setting
  reset-ticks ; so age can be computed
  reset-timer
  set initial-random-seed random 4294967295 - 2147483648
  random-seed initial-random-seed
  set network-names [ "criminal-links" "household-links" "partner-links" "sibling-links" "offspring-links" "friendship-links" "professional-links" "school-links" ]
  set network-used  [  0                0                  0              0               0                 0                  0                    0             ]
  load-stats-tables
  set facilitator-fails 0
  set facilitator-crimes 0
  ask patches [ set pcolor white ]
  setup-default-shapes
  setup-education-levels
  init-breed-colors
  setup-persons-and-friendship
  setup-schools
  init-students
  assign-jobs-and-wealth
  setup-inactive-status
  if unemployment-multiplier != "base" [ fix-unemployment unemployment-multiplier ]
  generate-households
  setup-siblings
  setup-employers-jobs
  ask persons with [ my-job = nobody and my-school = nobody and age >= 16 and age < retirement-age and job-level > 1 ] [ find-job ]
  init-professional-links
  calculate-crime-multiplier
  calculate-criminal-tendency
  calculate-arrest-rate
  setup-oc-groups
  setup-facilitators
  reset-oc-embeddedness
  ask turtles [ set-turtle-color-pos ]
  ask links [ set-link-color ]
  let networks-output-parameters csv:from-file "./networks/parameters.csv"
  set network-saving-list []
  foreach networks-output-parameters [ p ->
    let parameterkey (item 0 p)
    let parametervalue (item 1 p)
    if  parameterkey = "network-saving-interval" [ set network-saving-interval parametervalue ]
    if  parametervalue = "yes" [ set network-saving-list lput parameterkey network-saving-list ]
  ]
  let model-output-parameters csv:from-file "./outputs/parameters.csv"
  foreach model-output-parameters [ p ->
    let parameterkey (item 0 p)
    let parametervalue (item 1 p)
    if parameterkey = "model-saving-interval" [ set model-saving-interval parametervalue ]
  ]
  set this-is-a-big-crime       3
  set good-guy-threshold        0.6
  set big-crime-from-small-fish 0  ; to add in behaviorspace reporters
  ask persons [set hobby random 5] ; hobby is used only in wedding procedure to compute wedding sim.
  set removed-fatherships []
  calc-correction-for-non-facilitators
  show (word "Setup complete in " timer " s.")
end

to setup-facilitators
  ask persons [
    set facilitator?
      ifelse-value (not oc-member? and age > 18 and (random-float 1 < percentage-of-facilitators))
      [ true ] [ false ]
  ]
end

to load-stats-tables
  set num-co-offenders-dist but-first csv:from-file "inputs/general/data/num_co_offenders_dist.csv"
  set fertility-table group-by-first-two-items read-csv "initial_fertility_rates"
  set mortality-table group-by-first-two-items read-csv "initial_mortality_rates"
  set edu group-by-first-of-three read-csv "../../palermo/data/edu"
  set edu_by_wealth_lvl group-couples-by-2-keys read-csv "../../palermo/data/edu_by_wealth_lvl"
  set work_status_by_edu_lvl group-couples-by-2-keys read-csv "../../palermo/data/work_status_by_edu_lvl"
  set wealth_quintile_by_work_status group-couples-by-2-keys read-csv "../../palermo/data/wealth_quintile_by_work_status"
  set punishment-length-list read-csv "conviction_length"
  set male-punishment-length-list map [ i -> (list (item 0 i) (item 2 i)) ] punishment-length-list
  set female-punishment-length-list map [ i -> (list (item 0 i) (item 1 i)) ] punishment-length-list
  set jobs_by_company_size table-map table:group-items read-csv "../../palermo/data/jobs_by_company_size" [ line -> first line  ]   [ rows -> map but-first rows ]
  set c-range-by-age-and-sex group-couples-by-2-keys read-csv "crime_rate_by_gender_and_age_range"
  set c-by-age-and-sex group-by-first-two-items read-csv "crime_rate_by_gender_and_age"
  set labour-status-by-age-and-sex group-by-first-two-items read-csv "labour_status"
  set labour-status-range group-by-first-two-items read-csv "labour_status_range"
  ; further sources:
  ; schools.csv table goes into education-levels
  let marr item 0 but-first csv:from-file "inputs/general/data/marriages_stats.csv"
  set number-weddings-mean item 0 marr
  set number-weddings-sd item 1 marr
end

to wedding
  let updated-weddings-mean (number-weddings-mean * count all-persons / 1000) / 12
  let num-wedding-this-month random-poisson updated-weddings-mean
  if num-wedding-this-month < 0 [ set num-wedding-this-month 0 ]
  let maritable persons with [ age > 25 and age < 55 and partner = nobody ]
  let ego one-of maritable
  while [ num-wedding-this-month > 0 and any? maritable ] [
    ask ego [
      let pool nobody
      nw:with-context maritable friendship-links [ set pool (nw:turtles-in-radius max-accomplice-radius) ]
      nw:with-context maritable professional-links [ set pool (turtle-set pool (nw:turtles-in-radius max-accomplice-radius)) ]
      set pool filter-maritable other pool
      set maritable other maritable
      ifelse not any? pool
      [ set ego one-of maritable ]
      [ let my-partner rnd:weighted-one-of pool [ wedding-proximity-with myself ]
        ask my-partner [ set maritable other maritable ]
        set num-wedding-this-month num-wedding-this-month - 1
        set number-weddings number-weddings + 1
        conclude-wedding pool my-partner ]
    ]
  ]
end

to-report filter-maritable [ pool ]
  report pool with [ male? != ([ male? ] of myself) and (abs (age - ([ age ] of myself))) < 8 and
    not (sibling-link-neighbor? myself or offspring-link-neighbor? myself) ]
end

; person procedure
to-report my-family-links
  report (link-set my-sibling-links my-offspring-links my-partner-links)
end

; household or not?
to-report family-link-neighbors
  report (turtle-set sibling-link-neighbors offspring-link-neighbors partner-link-neighbors)
end

; should we have criminal network here, or not? What about household links?
to-report my-person-links
  report (link-set
    my-sibling-links
    my-offspring-links
    my-partner-links
    my-household-links
    my-friendship-links
    my-criminal-links
    my-professional-links
    my-school-links)
end

to-report person-link-neighbors
  report (turtle-set
    sibling-link-neighbors
    offspring-link-neighbors
    partner-link-neighbors
    household-link-neighbors
    friendship-link-neighbors
    criminal-link-neighbors
    professional-link-neighbors
    school-link-neighbors)
end

to-report person-links
    report (link-set
    sibling-links
    offspring-links
    partner-links
    household-links
    friendship-links
    criminal-links
    professional-links
    school-links)
end

to conclude-wedding [ pool my-partner ]
  ask my-household-links [ die ]
  set partner my-partner
  ask my-partner [
    ask my-household-links [ die ]
    set partner myself
  ]
  create-household-link-with my-partner
  create-partner-link-with my-partner
end

to-report wedding-proximity-with [ p-partner ]
  let social-proxy social-proximity-with p-partner
  let wedding-proxy (4 - (abs (hobby - [ hobby ] of p-partner))) / 4
  report (social-proxy + wedding-proxy) / 2
end

to go
  ask all-persons [
    set age calculate-age
    set num-crimes-committed-this-tick 0
  ]
  set number-law-interventions-this-tick 0
  if (network-saving-interval > 0) and ((ticks mod network-saving-interval) = 0) [
    dump-networks
  ]
  if (model-saving-interval > 0) and ((ticks mod model-saving-interval) = 0)[
    dump-model
  ]
  ; intervention clock
  if intervention-on? [
    if family-intervention != "none"   [ family-intervene        ]
    if social-support      != "none"   [ socialization-intervene ]
    if welfare-support     != "none"   [ welfare-intervene       ]
    ; OC-members-scrutiny works directly in factors-c
    ; OC-members-repression works in arrest-probability-with-intervention in commmit-crime
  ]
  ; things we only update yearly
  if ((ticks mod ticks-per-year) = 0) [ ; this should be 11, probably, otherwise
    calculate-criminal-tendency
    calculate-crime-multiplier ; we should update it, if population change
    graduate-and-enter-jobmarket
    ; updates neet status only when changing age range        (the age is a key of the table)
    ask persons with [ job-level < 2 and just-changed-age? and member? list age male? table:keys labour-status-range ] [
      update-unemployment-status
    ]
    ask persons with [
      my-school = nobody and age >= 18 and age < retirement-age and my-job = nobody and
      not retired? and job-level > 1
    ] [
      find-job
      if my-job != nobody [
        let employees turtle-set [ current-employees ] of [ my-employer ] of my-job
        let conn decide-conn-number employees 20
        create-professional-links-with n-of conn other employees
      ]
    ]
    let-migrants-in
    return-kids
  ]
  calc-criminal-tendency-addme-for-weighted-extraction
  calc-criminal-tendency-subtractfromme-for-inverse-weighted-extraction
  wedding
  reset-oc-embeddedness
  commit-crimes
  retire-persons
  make-baby
  remove-excess-friends
  remove-excess-professional-links
  make-friends
  ask prisoners [
    set sentence-countdown sentence-countdown - 1
    if sentence-countdown = 0 [ set breed persons set shape "person"]
  ]
  ask links [ hide-link ]
  make-people-die
  foreach network-saving-list [ listname ->
    output (word listname ": " count links with [ breed = runresult listname ])
  ]
  output "------------------"
  if behaviorspace-experiment-name != "" [
    show (word behaviorspace-run-number "." ticks " t:" timer )
  ]
  tick
end

to-report intervention-on?
  report ticks mod ticks-between-intervention = 0 and
     ticks >= intervention-start and
     ticks <  intervention-end
end

to calculate-arrest-rate
  ; this gives the base probability of arrest, propotionally to the number of expected crimes in the first year.
  set arrest-rate number-arrests-per-year / ticks-per-year / number-crimes-yearly-per10k / 10000 * count persons
end

to dump-networks
  foreach network-saving-list [ listname ->
    let network-agentset links with [ breed = runresult listname ]
    if any? network-agentset [
      let network-file-name (word "networks/" ticks  "_"  listname  ".graphml")
      nw:with-context turtles runresult listname [
        nw:save-graphml network-file-name
      ]
    ]
  ]
end

to calc-criminal-tendency-addme-for-weighted-extraction
  set criminal-tendency-addme-for-weighted-extraction ifelse-value (min [ criminal-tendency ] of persons < 0)
    [ -1 *  min [ criminal-tendency ] of persons ] [ 0 ]
end

to calc-criminal-tendency-subtractfromme-for-inverse-weighted-extraction
  set criminal-tendency-subtractfromme-for-inverse-weighted-extraction ifelse-value (max [ criminal-tendency ] of persons > 0)
    [ max [ criminal-tendency ] of persons ] [ 0 ]
end

to socialization-intervene
  let potential-targets all-persons with [ age <= 18 and age >= 6 and my-school != nobody ]
  let targets rnd:weighted-n-of ceiling (targets-addressed-percent / 100 * count potential-targets) potential-targets [
    criminal-tendency + criminal-tendency-addme-for-weighted-extraction
  ]
  if social-support = "educational" or social-support = "all" [
    soc-add-educational targets
  ]
  if social-support = "psychological" or social-support = "all" [
    soc-add-psychological targets
  ]
  if social-support = "more friends" or social-support = "all" [
    soc-add-more-friends targets
  ]
  if social-support = "all" [ ; also give a job to the mothers
    welfare-createjobs (turtle-set [ in-offspring-link-neighbors ] of targets) with [ not male? ]
  ]
end

to soc-add-educational [ targets ]
    ask targets [ set max-education-level min list (max-education-level + 1) (max table:keys education-levels) ]
end

to soc-add-psychological [ targets ]
  ; we use a random sample (arbitrarily set to 50 people size max) to avoid weighting sample from large populations
  ask targets [
    let support-set other persons with [
      num-crimes-committed = 0 and age > [ age ] of myself
    ]
    if any? support-set [
      let chosen rnd:weighted-one-of (limited-extraction support-set)  [ 1 - (abs (age - [ age ] of myself ) / 120) ]
      create-friendship-link-with chosen
    ]
  ]
end

to-report limited-extraction [ the-set ]
  report ifelse-value (count the-set > 50) [ n-of 50 the-set ][ the-set ]
end

to soc-add-more-friends [ targets ]
  ask targets [
    let support-set other persons
    if any? support-set [
      create-friendship-link-with rnd:weighted-one-of (limited-extraction support-set) [
        criminal-tendency-subtractfromme-for-inverse-weighted-extraction - criminal-tendency
      ]
    ]
  ]
end

to welfare-intervene
  let the-employer nobody
  let targets no-turtles
  ifelse welfare-support = "job-mother" [
    set targets all-persons with [ not male? and any? partner-link-neighbors with [ oc-member? ] and my-job = nobody ]
  ][
    if welfare-support = "job-child" [
      set targets all-persons with [ age > 16 and age < 24
        and not any? my-school-links
        and any? in-offspring-link-neighbors with [ male? and oc-member? ]
        and my-job = nobody ]
    ]
  ]
  if any? targets [
    set targets n-of ceiling (targets-addressed-percent / 100 * count targets) targets
    welfare-createjobs targets
  ]
end

to welfare-createjobs [ targets ]
  let the-employer nobody
  if any? targets [
    ask targets [
      let target self
      set the-employer one-of employers
      ask the-employer [
        hatch-jobs 1 [
          set my-employer myself
          ask my-employer [ set my-jobs (turtle-set my-jobs myself) ]
          set label self
          if [ job-level ] of target < 2 [ ask target [ set  job-level 2 ] ]
          set job-level [ job-level ] of target
          set my-worker target
          ask target [
            set my-job myself
            let employees [ current-employees ] of the-employer
            let conn decide-conn-number employees 20
            create-professional-links-with n-of conn other employees
          ]
        ]
      ]
    ]
  ]
end

to family-intervene
  let the-condition nobody
  ifelse family-intervention = "remove-if-caught" [
    set the-condition [ -> breed = prisoners ]
  ][
    ifelse family-intervention = "remove-if-OC-member" [
      set the-condition [ -> oc-member? ]
    ][
      if family-intervention = "remove-if-caught-and-OC-member" [
        set the-condition  [ -> oc-member? and breed = prisoners ]
      ]
    ]
  ]
  let kids-to-protect persons with [
    age < 18 and age >= 12 and any? in-offspring-link-neighbors with [
      male? and oc-member? and runresult the-condition
    ]
  ]
  if any? kids-to-protect [
    ask n-of ceiling (targets-addressed-percent / 100 * count kids-to-protect) kids-to-protect [
      set kids-intervention-counter kids-intervention-counter + 1
      ; notice that the intervention acts on ALL family members respecting the condition, causing double calls for families with double targets.
      ; gee but how comes that it increases with the nubmer of targets? We have to do better here
      let father one-of in-offspring-link-neighbors with [ male? and oc-member? ]
      ; this also removes household links, leaving the household in an incoherent state.
      ask my-in-offspring-links with [ other-end = father ] [ die ]
      set removed-fatherships fput (list ((18 * ticks-per-year + birth-tick) - ticks) father self) removed-fatherships
      ; at this point bad dad is out and we help the remaining with the whole package
      let family (turtle-set self family-link-neighbors)
      welfare-createjobs family with [
        my-job = nobody and age >= 16
        and not any? my-school-links
      ]
      soc-add-educational family with [
        my-job = nobody and age < 18
      ]
      soc-add-psychological family
      soc-add-more-friends family
    ]
  ]
end

to return-kids
  foreach removed-fatherships [ a ->
    ; list tick father son
    let father last but-last a
    if any? turtle-set father [
      if [ age ] of last a >= 18 [
        if (random-float 1) < 6 / (first a) [
          ask last a [ create-offspring-link-from father ]
          set removed-fatherships remove a removed-fatherships
        ]
      ]
    ]
  ]
end

to dump-model
  let model-file-name (word "outputs/" ticks "_model" ".world")
  export-world model-file-name
end

to-report potential-friends
  report (turtle-set
    family-link-neighbors
    school-link-neighbors
    professional-link-neighbors
  ) with [ not friendship-link-neighbor? myself ]
end

; update to use generic search mechanism
to make-friends
  ask persons [
    let reachable potential-friends
    let num-new-friends min list random-poisson 3 count reachable ; add slider
    ask rnd:weighted-n-of num-new-friends reachable
    [ social-proximity-with myself ]
    [ create-friendship-link-with myself ]
  ]
end

to remove-excess-friends
  ask persons [
    let num-friends count my-friendship-links
    if num-friends > dunbar-number [
      ask n-of (num-friends - dunbar-number) my-friendship-links [ die ]
    ]
  ]
end

to remove-excess-professional-links
  ask persons [
    let num-friends count my-professional-links
    if num-friends > 30 [
      ask n-of (num-friends - 30) my-professional-links [ die ]
    ]
  ]
end

to-report dunbar-number ; person reporter
  report 150 - abs (age - 30)
end

to setup-oc-groups
  ; OC members are scaled down if we don't have 10K agents
  let scaled-num-oc-families ceiling (num-oc-families * num-persons / 10000 * num-oc-persons / 30)
  let scaled-num-oc-persons  ceiling (num-oc-persons  * num-persons / 10000)
  ask rnd:weighted-n-of scaled-num-oc-families persons [
    criminal-tendency + criminal-tendency-addme-for-weighted-extraction
  ] [
    set oc-member? true
  ]
  let suitable-candidates-in-families persons with [
    age > 18 and not oc-member? and any? household-link-neighbors with [ oc-member? ]
  ]
  ; fill up the families as much as possible
  ask rnd:weighted-n-of min (list count suitable-candidates-in-families (scaled-num-oc-persons - scaled-num-oc-families))
  suitable-candidates-in-families [
    criminal-tendency + criminal-tendency-addme-for-weighted-extraction
  ] [
    set oc-member? true
  ]
  ; take some more if needed (note that this modifies the count of families)
  ask rnd:weighted-n-of (scaled-num-oc-persons - count persons with [ oc-member? ])
  persons with [ not oc-member? ] [
    criminal-tendency + criminal-tendency-addme-for-weighted-extraction ] [ set oc-member? true ]
  ask persons with [ oc-member? ] [
    create-criminal-links-with other persons with [ oc-member? ] [
      set num-co-offenses 1
    ]
  ]
end

to-report agentsets-from-table [ the-table ]
  ; given a table havings lists of agents as values,
  ; reports a list of agentsets.
  report map [ k ->
    turtle-set table:get the-table k
  ] filter [ k -> k != "NA" ] table:keys the-table
end

to put-self-in-table [ the-table the-key ] ; person command
  let the-list table:get-or-default the-table the-key []
  table:put the-table the-key lput self the-list
end

to reset-oc-embeddedness
  ask meta-links [ die ]
  ask persons [ set cached-oc-embeddedness nobody ]
end

to setup-default-shapes
  foreach (list
    (list persons         "person")
    (list jobs            "circle")
    (list employers       "pentagon")
    (list schools         "house colonial")
  ) [ p -> set-default-shape first p last p ]
end

to init-breed-colors
  let breeds map [ b -> (word b) ] remove-duplicates [ breed ] of turtles
  set breed-colors table:from-list (map [ [b i] ->
    (list b lput 80 (hsb ((360 / length breeds) * i) 50 80))
  ] breeds (range length breeds))
end

to set-turtle-color-pos ; turtle command
  set color table:get-or-default breed-colors (word breed) grey
  set label-color hsb (item 0 extract-hsb color) 50 20
  setxy random-xcor random-ycor
  hide-turtle
end

to set-link-color ; turtle command
  set color table:get-or-default breed-colors (word breed) grey
  hide-link
end

to setup-persons-and-friendship
  let age-gender-dist read-csv "initial_age_gender_dist"
  ; Using Watts-Strogatz is a bit arbitrary, but it should at least give us
  ; some clustering to start with. The network structure should evolve as the
  ; model runs anyway. Still, if we could find some data on the properties of
  ; real world friendship networks, we could use something like
  ; http://jasss.soc.surrey.ac.uk/13/1/11.html instead.]
  nw:generate-watts-strogatz persons friendship-links num-persons 2 0.1 [
    init-person age-gender-dist
  ]
end

to-report up-to-n-of-other-with [ n p ]
  let result []
  ask other persons [
    if (runresult p self) [
      if length result < n
      [ set result lput self result ]
    ]
  ]
  report (turtle-set result)
end

to setup-siblings
  ask persons with [ any? out-offspring-link-neighbors ] [ ; simulates people who left the original household.
    let num-siblings random-poisson 0.5 ;the number of links is N^3 agents, so let's keep this low
                                        ; at this stage links with other persons are only relatives inside households and friends.
    let p [ t -> any? out-offspring-link-neighbors and not link-neighbor? myself and abs age - [ age ] of myself < 5 ]
    let candidates up-to-n-of-other-with 50 p
    ; remove couples from candidates and their neighborhoods
    let all-potential-siblings [ -> (turtle-set self candidates sibling-link-neighbors [ sibling-link-neighbors ] of candidates)]
    let check-all-siblings [ ->
      any? (runresult all-potential-siblings) with [
        any? (runresult all-potential-siblings) with [ partner-link-neighbor? myself ] ]
    ]
    while [ count candidates > 0 and runresult check-all-siblings ] [
      ; trouble should exist, or check-all-siblings would fail
      let trouble one-of candidates with [ any? partner-link-neighbors or any? turtle-set [ partner-link-neighbors ] of myself ]
      ask trouble [ set candidates other candidates ]
    ]
    let targets (turtle-set self n-of min (list count candidates num-siblings) candidates)
    ask targets [ create-sibling-links-with other targets ]
    let other-targets (turtle-set targets [ sibling-link-neighbors ] of targets)
    ask turtle-set [ sibling-link-neighbors ] of targets [
      create-sibling-links-with other other-targets
    ]
  ]
end

to init-person [ age-gender-dist ] ; person command
  let row rnd:weighted-one-of-list age-gender-dist last ; select a row from our age-gender distribution
  set birth-tick 0 - (item 0 row) * ticks-per-year      ; ...and set age...
  init-person-empty
  set male? (item 1 row)                                ; ...and gender according to values in that row.
  set retired? age >= retirement-age                    ; persons older than retirement-age are retired
  ; education level is chosen, job and wealth follow in a conditioned sequence
  set max-education-level tune-edu pick-from-pair-list table:get edu male?
  set education-level max-education-level
  limit-education-by-age
end

to assign-jobs-and-wealth
  ask persons [
    ifelse age > 16 [
      set job-level pick-from-pair-list table:get work_status_by_edu_lvl list education-level male?
      set wealth-level pick-from-pair-list table:get wealth_quintile_by_work_status list job-level male?
    ] [
      set job-level 1
      set wealth-level 1 ; this will be updated by family membership
    ]
    ; this is just a first assignment, and will be modified first by the multiplier then by adding neet status.
  ]
end

to setup-inactive-status
  ask persons [
      if (age > 14 and age < 65 and job-level = 1 and random-float 1 < (item 0 table:get labour-status-by-age-and-sex list male? age) ) [
      set job-level 0
    ]
  ]
end

to-report tune-edu [ level ]
  if education-rate = 1 [ report level ]
  if random-float 1 < abs (education-rate - 1) [ ; modify it
    set level level + ifelse-value (education-rate > 1) [ 1 ] [ -1 ]
    if level > 4 [ set level 4 ]
    if level < 1 [ set level 1 ]
  ]
  report level
end

to init-person-empty ; person command
  set num-crimes-committed 0
  set num-crimes-committed-this-tick 0
  ; some agents should probably have a few initial crimes at start
  set education-level 0                                 ; we set starting education level in init-students
  set max-education-level 0 ; useful only for children, will be updated in that case
  set wealth-level 1 ; this will be updated by family membership
  set propensity lognormal nat-propensity-m nat-propensity-sigma   ; natural propensity to crime  propensity
  set oc-member? false                                  ; the seed OC network are initialised separately
  set retired? false
  set partner nobody
  set number-of-children 0
  set my-job nobody
  set facilitator? false
  set hobby random 5
  set-turtle-color-pos
  set male? one-of [ true false ]
  set migrant? false
  set age calculate-age
  set my-school nobody
  set target-of-intervention false
  set new-recruit -2
end

to let-migrants-in
  if migration-on? [
    ; calculate the difference between deaths and birth
    let to-replace max list 0 (num-persons - count all-persons)
    let free-jobs jobs with [ my-worker = nobody ]
    let num-to-add min (list to-replace count free-jobs)
    set number-migrants number-migrants + num-to-add
    ask n-of num-to-add free-jobs [
      ; we do not care about education level and wealth of migrants, as those variables
      ; exist only in order to generate the job position.
      hatch-persons 1 [
        init-person-empty
        set my-job myself
        ask my-job [ set my-worker myself ]
        let employees turtle-set [ current-employees ] of [ my-employer ] of my-job
        let conn decide-conn-number employees 20
        create-professional-links-with n-of conn other employees
        set birth-tick ticks - (random 20 + 18) * ticks-per-year
        set age calculate-age
        set wealth-level [ job-level ] of myself
        set migrant? true
      ]
    ]
  ]
end

to make-baby
  ifelse constant-population? [
    let breeding-target num-persons - count all-persons
    if breeding-target > 0 [
      let breeding-pool n-of (breeding-target * 10) persons with [ not male? and age >= 14 and age <= 50 ]
      ask rnd:weighted-n-of breeding-target breeding-pool [ p-fertility ] [ init-baby ]
    ]
  ] [
    ask persons with [ not male? and age >= 14 and age <= 50 ] [
      if random-float 1 < p-fertility [ init-baby ]
    ]
  ]
end

to init-baby ; person procedure
  ; we stop counting after 2 because probability stays the same
  set number-of-children number-of-children + 1
  set number-born number-born + 1
  hatch-persons 1 [
    set wealth-level [ wealth-level ] of myself
    set birth-tick ticks
    init-person-empty
    ask [ offspring-link-neighbors ] of myself [
      create-sibling-links-with other [ offspring-link-neighbors ] of myself
    ]
    create-household-links-with (turtle-set myself [ household-link-neighbors ] of myself)
    create-offspring-links-from (turtle-set myself [ partner-link-neighbors ] of myself)
    let dad one-of in-offspring-link-neighbors with [ male? ]
    set max-education-level ifelse-value (any? turtle-set dad) [
      [ max-education-level ] of dad
    ][
      [ max-education-level ] of myself
    ]
  ]
end

; this deforms a little the initial setup
to limit-education-by-age ; person command
  foreach reverse sort table:keys education-levels [ i ->
    let max-age first but-first table:get education-levels i
    if age <= max-age or education-level > max-education-level [ set education-level i - 1 ]
  ]
end

to-report calculate-age
  report floor ((ticks - birth-tick) / ticks-per-year)
end

to setup-employers-jobs
  output "Setting up employers"
  let job-counts reduce sentence read-csv "employer_sizes"
  ;; a small multiplier is added so to increase the pool to allow for matching at the job level
  let jobs-target (count persons with [ job-level > 1 and my-school = nobody and age > 16 and age < 65 ]) * 1.2
  while [ count jobs < jobs-target ] [
    let n (one-of job-counts)
    create-employers 1 [
      set my-jobs nobody
      hatch-jobs n [
        set my-employer myself
        ask my-employer [ set my-jobs (turtle-set my-jobs myself) ]
        set job-level random-level-by-size n
        set my-worker nobody
        set label self
      ]
      set label self
    ]
  ]
end

to-report random-level-by-size [ employer-size ]
  ifelse table:has-key? jobs_by_company_size employer-size [
    report pick-from-pair-list table:get jobs_by_company_size employer-size
  ] [
    let min-dist 1E10
    let most-similar-key -1
    foreach table:keys  jobs_by_company_size [ k ->
      if abs (employer-size - k) < min-dist [
        set most-similar-key k
        set min-dist abs (employer-size - k)
      ]
    ]
    report pick-from-pair-list table:get jobs_by_company_size most-similar-key
  ]
end

to find-job ; person procedure
  let the-job one-of jobs with [ my-worker = nobody and job-level = [ job-level ] of myself ]
  if the-job = nobody [
    set the-job one-of jobs with [ my-worker = nobody and job-level < [ job-level ] of myself ]
  ]
  if the-job != nobody [
    set my-job the-job
    ask the-job [ set my-worker myself ]
  ]
end

to-report current-employees ; employer reporter
  report turtle-set [ my-worker ] of my-jobs
end

to-report decide-conn-number [ people max-lim ]
  report ifelse-value (count people <= max-lim) [ count people - 1 ] [ max-lim ]
end

to init-professional-links
  ask employers [
    let employees current-employees
    let conn decide-conn-number employees 20
    ask employees [ create-professional-links-with n-of conn other employees ]
  ]
end

to assert [ f ]
  if not runresult f [ error (word "Assertion failed: " f) ]
end

to output [ str ]
  if output? [ output-show str ]
end

to setup-education-levels
  let list-schools read-csv "../../palermo/data/schools"
  set education-levels []
  let index 1
  foreach list-schools [ row ->
    let x ceiling ( ((item 3 row) / (item 4 row)) *  (num-persons) )
    let new-row replace-item 3 row x
    set new-row remove-item 4 new-row
    set education-levels lput (list index new-row) education-levels
    set index index + 1
  ]
  set education-levels table:from-list education-levels
end

to-report min-age-edu-level [ the-level ]
  report item 0 table:get education-levels the-level
end

to-report max-age-edu-level [ the-level ]
  report item 1 table:get education-levels the-level
end

; used in automated tests
to-report possible-school-level ; person command
  let the-level -1
  foreach table:keys education-levels [ i ->
    if age <= max-age-edu-level i and age >= min-age-edu-level i [ set the-level i ]
  ]
  report the-level
end

to setup-schools
  foreach table:keys education-levels [ level ->
    create-schools item 3 table:get education-levels level [
      set diploma-level level
      set my-students no-turtles
    ]
  ]
end

to init-students
  foreach table:keys education-levels [ level ->
    let row table:get education-levels level
    let start-age item 0 row
    let end-age   item 1 row
    ask persons with [ age >= start-age and age <= end-age and education-level = level - 1 ] [
      enroll-to-school level
    ]
  ]
  ask schools [
    let conn decide-conn-number my-students 15
    ask my-students [ create-school-links-with n-of conn other turtle-set [ my-students ] of myself ]
  ]
end

to enroll-to-school [ level ] ; person command
  let potential-schools (turtle-set [
    my-school
  ] of household-link-neighbors) with [ diploma-level = level ]
  ifelse any? potential-schools [
    set my-school one-of potential-schools
  ] [
    set my-school one-of schools with [ diploma-level = level ]
  ]
  ask my-school [ set my-students (turtle-set my-students myself) ]
end

to graduate-and-enter-jobmarket
  let primary-age item 0 table:get education-levels 1
  ask persons with [ education-level = 0 and age = primary-age and my-school = nobody ] [
    enroll-to-school 1
  ]
  ask schools [
    let end-age item 1 table:get education-levels diploma-level
    let school-education-level diploma-level
    ask my-students with [ age = (end-age + 1)] [
      leave-school
      set education-level school-education-level
      ifelse table:has-key? education-levels (school-education-level + 1) and
      (school-education-level + 1 <= max-education-level)
      [
        enroll-to-school (school-education-level + 1)
      ] [ ; otherwise, get a job level compatible with my education. Find-jobs will then try to assign the job. This includes the neet-check.
        set job-level pick-from-pair-list table:get work_status_by_edu_lvl list education-level male?
        set wealth-level pick-from-pair-list table:get wealth_quintile_by_work_status list job-level male?
        if (age > 14 and age < 65 and job-level = 1 and random-float 1 < (item 0 table:get labour-status-by-age-and-sex list male? age) ) [
          set job-level 0
        ]
      ]
    ]
  ]
end

to leave-school ; person command
  let other-students other turtle-set [ my-students ] of my-school
  ask my-school [ set my-students other-students ]
  set my-school nobody
end

to update-unemployment-status
  set job-level ifelse-value (random-float 1 < (item 0 table:get labour-status-by-age-and-sex list male? age)) [ 0 ] [ 1 ]
end

to-report link-color
  report [50 50 50 50]
end

to make-people-die
  ask all-persons [
    if random-float 1 < p-mortality or age > 119 [
      if facilitator? [
        let new-facilitator one-of other persons with [ not facilitator? and not oc-member? and age > 18 ]
        ask new-facilitator [ set facilitator? true ]
      ]
      set number-deceased number-deceased + 1
      if my-job != nobody [ ask my-job [ set my-worker nobody ] ]
      if my-school != nobody [ ask my-school [ set my-students other my-students ] ]
      if oc-member? [set dead-oc dead-oc + 1]
      die
    ]
  ]
end

to-report p-mortality
  let the-key list age male?
  ifelse (table:has-key? mortality-table the-key) [
    report (item 0 table:get mortality-table the-key)/ ticks-per-year
  ] [
    report 1 ; it there's no key, we remove the agent
  ]
end

to-report p-fertility
  let the-key list age min list number-of-children 2
  ifelse (table:has-key? fertility-table the-key) [
    report (item 0 table:get fertility-table the-key) / ticks-per-year
  ] [
    report 0
  ]
end

to calculate-crime-multiplier
  let total-crimes 0
  foreach table:keys c-range-by-age-and-sex [ cell ->
    let value last table:get c-range-by-age-and-sex cell
    let people-in-cell persons with [
      age > last cell and age <= first value and male? = first cell
    ]
    let n-of-crimes last value * count people-in-cell
    set total-crimes total-crimes + n-of-crimes
  ]
  set crime-multiplier number-crimes-yearly-per10k / 10000 * count all-persons / total-crimes
end

to increase-network-used
  let position-net position (word breed) network-names
  if (position-net != false)  [
    set network-used replace-item position-net network-used  ((item position-net network-used ) + 1)
  ]
end

to commit-crimes
  let co-offender-groups []
  let co-offenders-started-by-OC []
  foreach table:keys c-range-by-age-and-sex [ cell ->
    let value last table:get c-range-by-age-and-sex cell
    let people-in-cell persons with [
      age > last cell and age <= first value and male? = first cell
    ]
    let target-n-of-crimes last value * count people-in-cell / ticks-per-year * crime-multiplier
    repeat round target-n-of-crimes [
      set number-crimes number-crimes + 1
      ask rnd:weighted-one-of people-in-cell [ criminal-tendency + criminal-tendency-addme-for-weighted-extraction ] [
        let accomplices find-accomplices number-of-accomplices ; this takes care of facilitators as well.
        set co-offender-groups lput accomplices co-offender-groups
        if oc-member? [ set co-offenders-started-by-OC lput (list self accomplices) co-offenders-started-by-OC ]
        ; check for big crimes started from a normal guy
        if count accomplices > this-is-a-big-crime and criminal-tendency < good-guy-threshold [
          set big-crime-from-small-fish big-crime-from-small-fish +  1
        ]
      ]
    ]
  ]
  foreach co-offender-groups commit-crime
  if not empty? co-offender-groups [
    set co-offender-group-histo make-co-offending-histo co-offender-groups
  ]
  foreach co-offenders-started-by-OC [ co-offenders ->
    let originator item 0 co-offenders
    ask (item 1 co-offenders) with [ not oc-member? ] [
      set new-recruit ticks
      set oc-member? true
      set recruited recruited + 1
      ask my-links with [ other-end = originator ] [
        increase-network-used
      ]
      if any? in-offspring-link-neighbors with [ male? and oc-member? ] [
        set number-offspring-recruited-this-tick number-offspring-recruited-this-tick + 1
      ]
      if target-of-intervention [
        set number-protected-recruited-this-tick number-protected-recruited-this-tick + 1
      ]
    ]
  ]
  let criminals (turtle-set co-offender-groups)
  if-else (intervention-on? and facilitator-repression?) [
    ask criminals [ set arrest-weight ifelse-value (facilitator?) [ facilitator-repression-multiplier ] [ 1 ] ]
  ] [
    if-else (intervention-on? and OC-boss-repression? and any? criminals with [ oc-member? ]) [
      ask criminals with [ not oc-member? ] [ set arrest-weight 1 ]
      calc-OC-status criminals with [ oc-member? ]
    ] [ ; no intervention active
      ask criminals [ set arrest-weight 1 ]
    ]
  ]
  let target-n-of-arrests number-arrests-per-year / ticks-per-year / 10000 * count persons
  ; if I don't add some 1, for low levels of arrests and few agents nobody ever will be arrested.
  set target-n-of-arrests floor target-n-of-arrests + ifelse-value (random-float 1 < (target-n-of-arrests - floor target-n-of-arrests)) [ 1 ] [ 0 ]
  ask rnd:weighted-n-of target-n-of-arrests criminals [ arrest-weight ] [ get-caught ]
end

to-report make-co-offending-histo [ co-offender-groups ]
  let max-size max map count co-offender-groups + 1
  let counts n-values max-size [ 0 ]
  let i 0
  foreach co-offender-groups [ g ->
    set counts replace-item count g counts (item count g counts + 1)
  ]
  report counts
end

; of a group of criminals
to calc-OC-status [ oc-offenders ]
  ask oc-offenders [ set arrest-weight calc-OC-member-position ]
  let min-score min [ arrest-weight ] of oc-offenders
  let divide-score mean [ arrest-weight - min-score ] of oc-offenders
  ask oc-offenders [ set arrest-weight ifelse-value (divide-score = 0) [
      1
    ] [
      (arrest-weight - min-score) / divide-score
    ]
  ]
end

to-report calc-OC-member-position
  let n count my-links with [ [oc-member?] of other-end ]
  let myOCcrim my-criminal-links with [ [ oc-member? ] of other-end ]
  report n + sum [ num-co-offenses ] of myOCcrim - count myOCcrim ; subtracting the ones already counted above
end

to retire-persons
  ask persons with [ age >= retirement-age and not retired? ] [
    set retired? true
    if my-job != nobody [ ask my-job [ set my-worker nobody ] ]
    set my-job nobody
    ask my-professional-links [ die ]
    ; Figure out how to preserve socio-economic status (see issue #22)
  ]
end

to-report find-accomplices [ n ] ; person reporter. Reports a turtleset including the caller.
  if n = 0 [ report turtle-set self ]
  let d 1 ; start with a network distance of 1
  let accomplices no-turtles
  let facilitator-needed? n >= threshold-use-facilitators and not facilitator?
  if facilitator-needed? [ set n n - 1 ] ; save a slot for the facilitator
  ; first create the group
  nw:with-context persons person-links [
    while [ count accomplices < n and d <= max-accomplice-radius ] [
      let candidates sort-on [
        candidate-weight
      ] (turtle-set nw:turtles-in-radius d nw:turtles-in-reverse-radius d) with [ nw:distance-to myself = d ]
      while [ count accomplices < n and not empty? candidates ] [
        let candidate first candidates
        set candidates but-first candidates
        set accomplices (turtle-set candidate accomplices)
        if facilitator-needed? and [ facilitator? ] of candidate [ set n n + 1 set facilitator-needed? false ]
      ]
      set d d + 1
    ]
    if facilitator-needed? [
      ; Search a facilitator into my networks
      let available-facilitators turtle-set [
        (turtle-set nw:turtles-in-radius max-accomplice-radius nw:turtles-in-reverse-radius max-accomplice-radius) with [
          facilitator?
        ]
      ] of accomplices
      if any? available-facilitators [ set accomplices (turtle-set available-facilitators accomplices) ]
    ]
  ]
  if count accomplices < n [ set crime-size-fails crime-size-fails + 1 ]
  set accomplices (turtle-set self accomplices)
  if n >= threshold-use-facilitators [
    ifelse any? accomplices with [ facilitator? ] [
      set facilitator-crimes facilitator-crimes + 1
    ] [
      set facilitator-fails facilitator-fails + 1
    ]
  ]
  report accomplices
end

to commit-crime [ co-offenders ] ; observer command
  ask co-offenders [
    set num-crimes-committed num-crimes-committed + 1
    set num-crimes-committed-this-tick num-crimes-committed-this-tick + 1
    create-criminal-links-with other co-offenders
  ]
  ask criminal-links [ set co-off-flag 0 ]
  ask co-offenders [ ask my-criminal-links [ set co-off-flag co-off-flag + 1 ] ]
  ask criminal-links with [ co-off-flag = 2 ] [ set num-co-offenses num-co-offenses + 1 ]
end

to get-caught
  set number-law-interventions-this-tick number-law-interventions-this-tick + 1
  set people-jailed people-jailed + 1
  set breed prisoners
  set shape "face sad"
  ifelse male?
  [ set sentence-countdown item 0 rnd:weighted-one-of-list male-punishment-length-list   [ [ p ] -> last p ] ]
  [ set sentence-countdown item 0 rnd:weighted-one-of-list female-punishment-length-list [ [ p ] -> last p ] ]
  set sentence-countdown sentence-countdown * punishment-length
  if my-job != nobody [
    ask my-job [ set my-worker nobody ]
    set my-job nobody
    set job-level 1
  ]
  if my-school != nobody [ leave-school ]
  ask my-professional-links [ die ]
  ask my-school-links [ die ]
  ; we keep the friendship links and the family links
end

; this is what in the paper is called r - this is r
;R is then operationalised as the proportion of OC members among the social relations of each individual (comprising family, friendship, school, working and co-offending relations)
to-report candidate-weight ; person reporter
  report -1 * ifelse-value [ oc-member? ] of myself [
    (social-proximity-with myself * oc-embeddedness * criminal-tendency)
  ] [
    (social-proximity-with myself * criminal-tendency)
  ]
end

to calculate-criminal-tendency
  foreach table:keys c-range-by-age-and-sex [ genderage ->
    let top-and-value item 0 table:get c-range-by-age-and-sex genderage
    let subpop all-persons with [ age >= item 1 genderage and age <= item 0 top-and-value and male? = item 0 genderage ]
    if any? subpop [
      let c item 1 top-and-value
      ; c is the cell value. Now we calcolate criminal-tendency with the factors.
      ask subpop [
        set criminal-tendency c
        foreach  factors-c [ x ->
          set criminal-tendency criminal-tendency * (runresult item 1 x)
        ]
      ]
      ; then derive the correction epsilon by solving $\sum_{i} ( c f_i + \epsilon ) = \sum_i c$
      let epsilon c - mean [ criminal-tendency ] of subpop
      ask subpop [
        set criminal-tendency criminal-tendency + epsilon
      ]
      assert [ -> abs (mean [ criminal-tendency ] of subpop - c) < 0.01 * c ]
    ]
  ]
  if intervention-on? [
    if facilitator-repression? [ calc-correction-for-non-facilitators ]
  ]
end

to calc-correction-for-non-facilitators
  let f count persons with [ facilitator? ]
  let n count persons
  set correction-for-non-facilitators ifelse-value (f > 0) [ (n - facilitator-repression-multiplier * f) / (n - f) ][ 1 ]
end

to-report social-proximity-with [ target ] ; person reporter
  let total 0
  let normalization 0
  ask target [
    foreach factors-social-proximity [ x ->
      set total (total + (item 1 x) * (runresult item 2 x))
      set normalization (normalization + (item 1 x))
    ]
  ]
  report total / normalization
end

to-report factors-social-proximity  ; person reporter.
  let ego myself
  let alter self
  report (list
    ;     var-name     weight    normalized-reporter
    (list "age"        1.0       [ -> ifelse-value (abs (age - [ age ] of ego) > 18) [ 0 ] [ 1 - abs (age - [ age ] of ego) / 18 ] ])
    (list "gender"     1.0       [ -> ifelse-value (male? = [ male? ] of ego) [ 1 ][ 0 ] ])
    (list "wealth"     1.0       [ -> ifelse-value (wealth-level = [ wealth-level ] of ego) [ 1 ][ 0 ] ])
    (list "education"  1.0       [ -> ifelse-value (education-level = [ education-level ] of ego) [ 1 ][ 0 ] ])
    (list "closure"    1.0       [ -> ifelse-value (any? (other [ friendship-link-neighbors ] of alter) with
                                      [ friendship-link-neighbor? ego ]) [ 1 ][ 0 ] ])
 )
end

; we do no track time of crime so for now the requirement of
; "at least one crime in the last 2 years." is not feasible.
; for now we use just "at least one crime."
to-report factors-c
  report (list
    ;     var-name     normalized-reporter
    (list "employment"   [ -> ifelse-value (job-level = 1)                   [ 1.30 ] [ 1.0 ] ])
    (list "education"    [ -> ifelse-value (education-level >= 2)            [ 0.94 ] [ 1.0 ] ])
    (list "propensity"   [ -> ifelse-value (propensity >
      exp (nat-propensity-m - nat-propensity-sigma ^ 2 / 2) + nat-propensity-threshold *
      sqrt (exp nat-propensity-sigma ^ 2 - 1) * exp (nat-propensity-m + nat-propensity-sigma ^ 2 / 2))
                                                                             [ 1.97 ] [ 1.0 ] ])
    (list "crim-hist"    [ -> ifelse-value (num-crimes-committed >= 0)       [ 1.62 ] [ 1.0 ] ])
    (list "crim-fam"     [ -> ifelse-value
      (any? family-link-neighbors and count family-link-neighbors with [ num-crimes-committed > 0 ] /
        count family-link-neighbors  > 0.5)                                  [ 1.45 ] [ 1.0 ] ])
    (list "crim-neigh"   [ -> ifelse-value
      ( (any? friendship-link-neighbors or any? professional-link-neighbors) and
        (count (turtle-set friendship-link-neighbors with [ num-crimes-committed > 0 ]
          professional-link-neighbors with [ num-crimes-committed > 0 ])) /
        (count (turtle-set friendship-link-neighbors professional-link-neighbors)) > 0.5)
                                                                             [ 1.81 ] [ 1.0 ] ])
    (list "oc-member"   [ -> ifelse-value (oc-member?)                       [ 4.50 ] [ 1.0 ] ])
  )
end

to-report oc-embeddedness ; person reporter
  if cached-oc-embeddedness = nobody [
    ; only calculate oc-embeddedness if we don't have a cached value
    nw:with-context all-persons person-links [
      set cached-oc-embeddedness 0 ; start with an hypothesis of 0
      let agents (turtle-set nw:turtles-in-radius oc-embeddedness-radius nw:turtles-in-reverse-radius oc-embeddedness-radius) ; this needs to include the caller
      let oc-members agents with [ oc-member? ]
      if any? other oc-members [
        update-meta-links agents
        nw:with-context agents meta-links [
          set cached-oc-embeddedness (find-oc-weight-distance oc-members / find-oc-weight-distance agents)
          ;          sum [ 1 / nw:weighted-distance-to myself dist ] of other oc-members /
          ;          sum [ 1 / nw:weighted-distance-to myself dist ] of other agents
          ;        )
        ]
      ]
    ]
  ]
  report cached-oc-embeddedness
end

to-report find-oc-weight-distance [ people ]
  report sum [ 1 / nw:weighted-distance-to myself dist ] of other people
end

to-report number-of-accomplices
  ; pick a group size from the num. co-offenders distribution
  ; and substract one to get the number of accomplices
  report (first rnd:weighted-one-of-list num-co-offenders-dist last) - 1
end

to update-meta-links [ agents ]
  nw:with-context agents person-links [ ; limit the context to the agents in the radius of interest
    ask agents [
      ask other (turtle-set nw:turtles-in-radius 1 nw:turtles-in-reverse-radius 1) [
        create-meta-link-with myself [ ; if that link already exists, it won't be re-created
          let w 0
          if [ household-link-with other-end ] of myself    != nobody [ set w w + 1 ]
          if [ friendship-link-with other-end ] of myself   != nobody [ set w w + 1 ]
          if [ school-link-with other-end ] of myself       != nobody [ set w w + 1 ]
          if [ professional-link-with other-end ] of myself != nobody [ set w w + 1 ]
          if [ partner-link-with other-end ] of myself      != nobody [ set w w + 1 ]
          if [ sibling-link-with other-end ] of myself      != nobody [ set w w + 1 ]
          if [ offspring-link-with other-end ] of myself    != nobody [ set w w + 1 ]
          if [ criminal-link-with other-end ] of myself     != nobody [
            set w w + [ num-co-offenses ] of [ criminal-link-with other-end ] of myself
          ]
          if w  = 0 [
            show [who] of myself show [breed] of links with [both-ends = [both-ends] of  myself]
          ]
          set dist 1 / w; the distance cost of the link is the inverse of its weight
        ]
      ]
    ]
  ]
end

to load-model
  let model-file-name user-file
  if is-string? model-file-name [
    let file-ext-position position ".world" model-file-name
    ifelse is-number? file-ext-position [ import-world model-file-name ]
                                        [ user-message "the file must have the extension .world" ]
  ]
end

to generate-households
  output "Generating households..."
  ; this mostly follows the third algorithm from Gargiulo et al. 2010
  ; (https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0008828)
  let head-age-dist group-by-first-item read-csv "head_age_dist_by_household_size"
  let proportion-of-male-singles-by-age table:from-list read-csv "proportion_of_male_singles_by_age"
  let hh-type-dist group-by-first-item read-csv "household_type_dist_by_age"
  let partner-age-dist group-by-first-item read-csv "../../palermo/data/partner_age_dist"
  let children-age-dist make-children-age-dist-table
  let p-single-father first first csv:from-file (word data-folder "proportion_single_fathers.csv")
  let population new-population-pool persons
  let hh-sizes household-sizes count persons
  let complex-hh-sizes [] ; will contain the sizes that we fail to generate: we'll reuse those for complex households
  let max-attempts-by-size 50
  ; We have two levels of iterating: the first level is the general attempts at generating a household
  ; and the second level is the attempts at generating a household of a particular size before giving up.
  foreach hh-sizes [ hh-size ->
    let success false
    let nb-attempts 0
    while [ not success and nb-attempts < max-attempts-by-size ] [
      set nb-attempts nb-attempts + 1
      ; pick the age of the head according to the size of the household
      let head-age pick-from-pair-list (table:get head-age-dist hh-size)
      ifelse hh-size = 1 [
        let male-wanted? random-float 1 < table:get proportion-of-male-singles-by-age head-age
        let head pick-from-population-pool-by-age-and-gender population head-age male-wanted?
        ; Note that we don't "do" anything with the picked head: the fact that it gets
        ; removed from the population table when we pick it is sufficient for us.
        set success (head != nobody)
      ] [
        ; For household sizes greater than 1, pick a household type according to age of the head
        let hh-type pick-from-pair-list (table:get hh-type-dist head-age)
        let male-head? ifelse-value (hh-type = "single parent") [ random-float 1 < p-single-father ] [ true ]
        let mother-age ifelse-value male-head? [ pick-from-pair-list (table:get partner-age-dist head-age) ] [ head-age ]
        let hh-members (list pick-from-population-pool-by-age-and-gender population head-age male-head?) ; start a list with the hh head
        if hh-type = "couple" [
          let mother pick-from-population-pool-by-age-and-gender population mother-age false
          set hh-members lput mother hh-members
        ]
        let num-children (hh-size - length hh-members)
        foreach (range 1 (num-children + 1)) [ child-no ->
          ifelse table:has-key? table:get children-age-dist child-no mother-age [
            let child-age pick-from-pair-list (table:get table:get children-age-dist child-no mother-age)
            let child pick-from-population-pool-by-age population child-age
            set hh-members lput child hh-members
          ] [
            ; We might not have an age distribution for some combinations of child no / mother age
            ; (for example, no 18 year-old mother has 8 children), so we add `nobody` to our member
            ; list in those case, to signal that the household generation has failed
            set hh-members lput nobody hh-members
          ]
        ]
        set hh-members filter is-person? hh-members ; exclude nobodies
        ifelse length hh-members = hh-size [ ; only generate the household if we got everyone we needed
          set success true
          let family-wealth-level [ wealth-level ] of item 0 hh-members
          if hh-type = "couple" [ ; if it's a couple, partner up the first two members and set the others as offspring
            ask item 0 hh-members [ set partner item 1 hh-members
              create-partner-link-with item 1 hh-members
            ]
            ask item 1 hh-members [ set partner item 0 hh-members ]
            let couple (turtle-set item 0 hh-members item 1 hh-members)
            let offspring turtle-set but-first but-first hh-members
            ask couple [ create-offspring-links-to offspring ]
            ask offspring [ create-sibling-links-with other offspring ]
          ]
          set hh-members turtle-set hh-members
          ask hh-members [ create-household-links-with other hh-members set wealth-level family-wealth-level ]
        ] [
          ; in case of failure, we need to put the selected members back in the population
          foreach hh-members [ m -> put-in-population-pool m population ]
        ]
      ]
    ]
    if not success [ set complex-hh-sizes lput hh-size complex-hh-sizes ]
  ]
  ; to generate complex households from the remaining population,
  ; we first flatten it into a list
  output word "complex size: " (word length complex-hh-sizes)
  set population [ self ] of population-pool-to-agentset population
  foreach complex-hh-sizes [ hh-size ->
    set hh-size min (list hh-size length population)
    let hh-members turtle-set sublist population 0 hh-size       ; grab the first persons in the list,
    set population sublist population hh-size length population  ; remove them from the population
    let family-wealth-level [ wealth-level ] of max-one-of hh-members [ age ]
    ask hh-members [ create-household-links-with other hh-members
      set wealth-level family-wealth-level ]                     ; and link them up.
  ]
end

to-report population-pool-to-agentset [ population ]
  report turtle-set table:values table-map population [ entry -> table:values entry ]
end

to-report household-sizes [ the-size ]
  let hh-size-dist read-csv "household_size_dist"
  let sizes []
  let current-sum 0
  while [ current-sum < the-size ] [
    let hh-size pick-from-pair-list hh-size-dist
    if current-sum + hh-size <= the-size [
      set sizes lput hh-size sizes
      set current-sum current-sum + hh-size
    ]
  ]
  report reverse sort sizes
end

to-report make-children-age-dist-table
  ; reports a two-level table where the first level is
  ; child number and the second level is the mother's age
  let csv-data read-csv "../../palermo/data/children_age_dist"
  report table-map (group-by-first-item csv-data) [ entry ->
    group-by-first-item entry
  ]
end

to-report pick-from-pair-list [ pairs ]
  ; picks the first item of a pair using the last item as the weight
  report first rnd:weighted-one-of-list pairs last
end

to-report read-csv [ base-file-name ]
  report but-first csv:from-file (word data-folder base-file-name ".csv")
end

to-report group-by-first-item [ csv-data ]
  let table table:group-items csv-data first ; group the rows by their first item
  report table-map table [ rows -> map but-first rows ] ; remove the first item of each row
end

to-report new-population-pool [ agents ]
  ; Create a two-level table to contain our population of agents, where the
  ; first level is the age and the second level is the gender. Agents inside
  ; the table are stored in lists because we are are going to need fast inserts
  let population table:make
  ask agents [ put-in-population-pool self population ]
  report population
end

to put-in-population-pool [ the-person population ]
  if not table:has-key? population [ age ] of the-person [
    table:put population [ age ] of the-person table:make
  ]
  let subtable table:get population [ age ] of the-person
  if not table:has-key? subtable [ male? ] of the-person [
    table:put subtable [ male? ] of the-person []
  ]
  let person-list table:get subtable [ male? ] of the-person
  table:put subtable [ male? ] of the-person lput the-person person-list
end

to-report pick-from-population-pool-by-age-and-gender [ population age-wanted male-wanted? ]
  ; Picks an agent with a given age and gender and removes it from the population pool.
  ; Reports `nobody` if it can't find an agent with the wanted age/gender
  if not table:has-key? population age-wanted [ report nobody ]
  let sub-table table:get population age-wanted
  if not table:has-key? sub-table male-wanted? [ report nobody ]
  let picked-person one-of table:get sub-table male-wanted?
  remove-from-population-pool picked-person population
  report picked-person
end

to-report pick-from-population-pool-by-age [ population age-wanted ]
  ; Picks an agent with a given age and removes it from the population pool.
  ; Reports `nobody` if it can't find an agent with the wanted age.
  if not table:has-key? population age-wanted [ report nobody ]
  let picked-person one-of turtle-set table:values table:get population age-wanted
  remove-from-population-pool picked-person population
  report picked-person
end

to remove-from-population-pool [ the-person population ]
  let the-age [ age ] of the-person
  let is-male? [ male? ] of the-person
  if table:has-key? population the-age [
    let sub-table table:get population the-age
    if table:has-key? sub-table is-male? [
      let old-list table:get sub-table is-male?
      let new-list filter [ a -> a != the-person ] old-list
      ifelse not empty? new-list [
        table:put sub-table is-male? new-list
      ] [
        table:remove sub-table is-male?
        if table:length sub-table = 0 [
          table:remove population the-age
        ]
      ]
    ]
  ]
end

to-report table-map [ tbl fn ]
  ; from https://github.com/NetLogo/Table-Extension/issues/6#issuecomment-276109136
  ; (if `table:map` is ever added to the table extension, this could be replaced by it)
  report table:from-list map [ entry ->
    list (first entry) (runresult fn last entry)
  ] table:to-list tbl
end

to-report group-by-first-two-items [ csv-data ]
  let table table:group-items csv-data [ line -> list first line first but-first line ]; group the rows by lists with the 2 leading items
  report table-map table [ rows -> map last rows ] ; remove the first two items of each row
end

to-report group-by-first-of-three [ csv-data ]
  let table table:group-items csv-data [ line -> (first line)]; group the rows by lists with the 1st item
  report table-map table [ rows -> map [ i -> (list last but-last i last i) ] rows ]
end

to-report group-couples-by-2-keys [ csv-data ]
  let table table:group-items csv-data [ line -> (list first line first but-first line)]; group the rows by lists with initial 2 items
  report table-map table [ rows -> map [ i -> (list last but-last i last i) ] rows ]
end

; reporter to check that the table is respected at the beginning,
; and to study how it will change in time.
; it should return the same data we have in Niccolo's "SES mechanism  (without firing & hirings)" file
; note that data comes out in a sequence wealth / gender / edu in which the right variable vary first
; in other words, for wealth/gender, [[1 true] [1 false] [2 true] [2 false]
; and it will need to be sorted for comparison (Niccolo's data comes gender/edu/wealth
; input should be one of our couple-indexed tables, that is, edu_by_wealth_lvl,  work_status_by_edu_lvl, wealth_quintile_by_work_status, criminal_propensity_by_wealth_quintile
to-report ses-stat-table [ three-variable-indexed-by-first-two-table ]
  report
  map [    key ->
    map [ line ->
      count persons with [ male? = item 1 key and education-level = item 0 line and wealth-level = item 0 key and age > 25 and age < 44] /
      count persons with [ male? and wealth-level = item 0 key and age > 25 and age < 44]
    ] table:get three-variable-indexed-by-first-two-table key
  ] table:keys three-variable-indexed-by-first-two-table
end

to-report the-families
  let components no-turtles
  nw:with-context persons household-links [
    set components nw:weak-component-clusters
  ]
  report components
end

to-report compare-edu-wealth-table
  report reduce sentence
  map [    key ->
    map [ line ->
      (item 1 line -
      count persons with [ male? = item 1 key and education-level = item 0 line and wealth-level = item 0 key and age > 25 and age < 44] /
      count persons with [ male? and wealth-level = item 0 key and age > 25 and age < 44])
    ] table:get edu_by_wealth_lvl key
  ] table:keys edu_by_wealth_lvl
end

; https://en.wikipedia.org/wiki/Atkinson_index
to-report atkinson-inequality-index [ epsilon person-reporter ]
  let mean-income sum [ wealth-level ] of all-persons / count all-persons
  report 1 - ((sum [ runresult person-reporter ] of all-persons) / count all-persons )^(1 - (1 - epsilon)) / mean-income
end

to-report all-persons
  report (turtle-set persons prisoners)
end

to-report lognormal [ mu sigma ]
  report exp (mu + sigma * random-normal 0 1)
end

to-report just-changed-age?
  report floor ((ticks - birth-tick) / ticks-per-year) = ((ticks - birth-tick) / ticks-per-year)
end
@#$#@#$#@
GRAPHICS-WINDOW
950
605
991
647
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
330
215
445
248
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
10
245
43
num-persons
num-persons
100
10000
2000.0
100
1
NIL
HORIZONTAL

MONITOR
810
110
925
155
NIL
count jobs
17
1
11

SWITCH
0
610
245
643
output?
output?
1
1
-1000

MONITOR
810
160
925
205
NIL
count links
17
1
11

INPUTBOX
0
480
245
540
ticks-per-year
12.0
1
0
Number

BUTTON
330
255
385
288
go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
390
255
445
288
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

OUTPUT
270
335
517
640
10

SLIDER
0
265
245
298
max-accomplice-radius
max-accomplice-radius
1
4
2.0
1
1
NIL
HORIZONTAL

SLIDER
0
300
245
333
oc-embeddedness-radius
oc-embeddedness-radius
1
4
2.0
1
1
NIL
HORIZONTAL

SLIDER
0
335
245
368
retirement-age
retirement-age
0
100
65.0
1
1
years old
HORIZONTAL

SLIDER
0
150
245
183
number-arrests-per-year
number-arrests-per-year
0
100
30.0
5
1
NIL
HORIZONTAL

MONITOR
810
210
925
255
NIL
count prisoners
17
1
11

PLOT
945
270
1285
425
Age distribution
age
count
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [ age ] of persons"

MONITOR
810
260
925
305
migrants
count persons with [ migrant? ]
17
1
11

MONITOR
810
310
925
355
dead
number-deceased
17
1
11

SLIDER
0
370
245
403
nat-propensity-m
nat-propensity-m
0
10
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
0
405
245
438
nat-propensity-sigma
nat-propensity-sigma
0
10
0.25
0.05
1
NIL
HORIZONTAL

SLIDER
0
440
245
473
nat-propensity-threshold
nat-propensity-threshold
0
2
1.0
0.1
1
sd
HORIZONTAL

SLIDER
0
45
245
78
num-oc-persons
num-oc-persons
2
200
30.0
1
1
NIL
HORIZONTAL

SLIDER
0
80
245
113
num-oc-families
num-oc-families
1
50
8.0
1
1
NIL
HORIZONTAL

MONITOR
810
360
925
405
NIL
number-born
17
1
11

MONITOR
810
61
925
106
OC members
count all-persons with [ oc-member? ]
17
1
11

CHOOSER
540
200
785
245
family-intervention
family-intervention
"none" "remove-if-caught" "remove-if-OC-member" "remove-if-caught-and-OC-member"
0

CHOOSER
540
245
785
290
social-support
social-support
"none" "educational" "psychological" "more friends" "all"
0

CHOOSER
540
290
785
335
welfare-support
welfare-support
"none" "job-mother" "job-child"
0

SLIDER
540
60
785
93
targets-addressed-percent
targets-addressed-percent
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
540
95
785
128
ticks-between-intervention
ticks-between-intervention
1
24
12.0
1
1
NIL
HORIZONTAL

SWITCH
540
340
785
373
OC-boss-repression?
OC-boss-repression?
1
1
-1000

SLIDER
540
130
785
163
intervention-start
intervention-start
0
100
13.0
1
1
NIL
HORIZONTAL

SLIDER
540
165
785
198
intervention-end
intervention-end
0
50
9999.0
1
1
NIL
HORIZONTAL

SLIDER
0
190
245
223
percentage-of-facilitators
percentage-of-facilitators
0
0.01
0.005
0.001
1
NIL
HORIZONTAL

SLIDER
0
225
245
258
threshold-use-facilitators
threshold-use-facilitators
0
10
4.0
1
1
NIL
HORIZONTAL

MONITOR
945
60
1060
105
facilitators
count persons with [facilitator?]
0
1
11

MONITOR
945
110
1060
155
NIL
facilitator-fails
17
1
11

MONITOR
945
160
1060
205
NIL
facilitator-crimes
17
1
11

MONITOR
945
10
1060
55
NIL
crime-size-fails
17
1
11

SLIDER
270
60
515
93
education-rate
education-rate
0
2
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
270
95
515
128
punishment-length
punishment-length
0.5
2
1.0
0.5
1
NIL
HORIZONTAL

CHOOSER
540
10
785
55
intervention
intervention
"use current values" "baseline" "preventive" "disruptive" "students" "facilitators" "preventive-strong" "disruptive-strong" "students-strong" "facilitators-strong"
1

MONITOR
810
410
925
455
employed
count persons with [ my-job != nobody ]
17
1
11

MONITOR
810
460
925
505
open positions
count jobs with [ my-worker = nobody ]
17
1
11

MONITOR
810
10
925
55
people
count all-persons
17
1
11

MONITOR
810
509
925
554
NIL
number-weddings
17
1
11

PLOT
1085
10
1286
130
c
tick
mean c
0.0
20.0
-0.1
0.1
true
false
"" ""
PENS
"c-pen" 1.0 0 -16777216 true "" "if any? all-persons [ plot  mean [ criminal-tendency ] of all-persons ]"

PLOT
1085
140
1286
260
mean education
tick
mean education
0.0
3.0
2.0
3.0
true
false
"" ""
PENS
"edu-pen" 1.0 0 -16777216 true "" "if any? all-persons [ plot mean [ education-level ] of all-persons ]"

CHOOSER
270
130
515
175
unemployment-multiplier
unemployment-multiplier
"base" 0.5 1.5 0.410067526089626 0.205033763044813 0.615101289134438
3

MONITOR
575
510
785
555
unemployed rate (level, percent)
count all-persons with [ job-level = 1 and age > 16 and age < 65 and my-school = nobody ] / count all-persons with [ my-school = nobody and age > 16 and age < 65 ] * 100
2
1
11

MONITOR
810
559
925
604
job mismatch
count all-persons with [ my-job = nobody and job-level > 1 and my-school = nobody and age > 16 and age < 65 ]
17
1
11

MONITOR
810
609
925
654
NIL
number-crimes
3
1
11

SLIDER
0
115
245
148
number-crimes-yearly-per10k
number-crimes-yearly-per10k
0
3000
2000.0
100
1
NIL
HORIZONTAL

MONITOR
575
560
785
605
Not looking for work (percent)
count all-persons with [ job-level = 0 and age > 16 and age < 65 and my-school = nobody ] / count all-persons with [ my-school = nobody and age > 16 and age < 65 ] * 100
2
1
11

MONITOR
575
610
785
655
occupied (level, percent)
count all-persons with [ job-level > 1 and age > 16 and age < 65 and my-school = nobody ] / count all-persons with [ my-school = nobody and age > 16 and age < 65 ] * 100
2
1
11

CHOOSER
270
10
515
55
data-folder
data-folder
"inputs/palermo/data/" "inputs/eindhoven/data/"
0

SWITCH
540
375
785
408
facilitator-repression?
facilitator-repression?
1
1
-1000

SLIDER
540
410
785
443
facilitator-repression-multiplier
facilitator-repression-multiplier
1
5
2.0
0.1
1
NIL
HORIZONTAL

SWITCH
0
540
245
573
migration-on?
migration-on?
0
1
-1000

SWITCH
0
575
245
608
constant-population?
constant-population?
1
1
-1000

PLOT
945
435
1285
585
OC members
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "let _w (all-persons with [ oc-member? ]) if (any? _w) [ plot count _w ]"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house colonial
false
0
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 45 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 60 195 105 240
Rectangle -16777216 true false 60 150 105 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Polygon -7500403 true true 30 135 285 135 240 90 75 90
Line -16777216 false 30 135 285 135
Line -16777216 false 255 105 285 135
Line -7500403 true 154 195 154 255
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 135 150 180 180

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Polygon -7500403 true true 30 30 270 30 270 270 30 270 30 150 60 150 60 240 240 240 240 60 60 60 60 150 30 150 30 30 60 45

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
