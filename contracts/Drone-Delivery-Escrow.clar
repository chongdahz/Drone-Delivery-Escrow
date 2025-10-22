;; title: Drone-Delivery-Escrow
;; version: 1.0.0
;; summary: Escrow system for drone deliveries with IoT confirmation
;; description: Smart contract that locks STX until IoT devices confirm successful drone delivery

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-ESCROW (err u101))
(define-constant ERR-ALREADY-CONFIRMED (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-TIMEOUT-NOT-REACHED (err u105))
(define-constant ERR-ALREADY-RELEASED (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-DISPUTE-EXISTS (err u108))
(define-constant ERR-OUTSIDE-GEOFENCE (err u109))
(define-constant ERR-INVALID-COORDINATES (err u110))
(define-constant ERR-ROUTE-NOT-FOUND (err u111))
(define-constant ERR-TRACKING-INACTIVE (err u112))
(define-constant ERR-GEOFENCE-NOT-SET (err u113))
(define-constant ERR-INSURANCE-NOT-FOUND (err u114))
(define-constant ERR-INSURANCE-ALREADY-PURCHASED (err u115))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u116))
(define-constant ERR-INSURANCE-NOT-ELIGIBLE (err u117))

(define-constant ESCROW-TIMEOUT u144)
(define-constant DISPUTE-TIMEOUT u288)

(define-constant STATUS-PENDING u0)
(define-constant STATUS-CONFIRMED u1)
(define-constant STATUS-RELEASED u2)
(define-constant STATUS-REFUNDED u3)
(define-constant STATUS-DISPUTED u4)

(define-data-var escrow-counter uint u0)
(define-data-var total-escrowed uint u0)
(define-data-var total-waypoints uint u0)
(define-data-var active-deliveries uint u0)
(define-data-var insurance-pool uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var base-insurance-rate uint u50)

(define-map escrows
  uint
  {
    customer: principal,
    merchant: principal,
    amount: uint,
    status: uint,
    created-at: uint,
    delivery-address: (string-ascii 100),
    iot-device: (optional principal),
    confirmation-hash: (optional (buff 32))
  }
)

(define-map iot-devices
  principal
  {
    authorized: bool,
    escrows-confirmed: uint,
    reputation: uint
  }
)

(define-map disputes
  uint
  {
    raised-by: principal,
    reason: (string-ascii 200),
    created-at: uint,
    resolved: bool,
    winner: (optional principal)
  }
)

(define-map merchant-profiles
  principal
  {
    name: (string-ascii 50),
    verified: bool,
    total-deliveries: uint,
    success-rate: uint
  }
)

(define-map delivery-routes
  uint
  {
    start-lat: int,
    start-lon: int,
    end-lat: int,
    end-lon: int,
    estimated-distance: uint,
    estimated-time: uint,
    tracking-active: bool,
    waypoint-count: uint
  }
)

(define-map tracking-waypoints
  {escrow-id: uint, waypoint-id: uint}
  {
    latitude: int,
    longitude: int,
    altitude: uint,
    timestamp: uint,
    speed: uint,
    battery-level: uint
  }
)

(define-map geofence-zones
  uint
  {
    center-lat: int,
    center-lon: int,
    radius-meters: uint,
    zone-type: uint,
    active: bool
  }
)

(define-map location-verifications
  uint
  {
    verified-lat: int,
    verified-lon: int,
    geofence-validated: bool,
    verification-timestamp: uint,
    distance-from-target: uint
  }
)

(define-map delivery-insurance
  uint
  {
    insured: bool,
    premium-paid: uint,
    coverage-amount: uint,
    risk-score: uint,
    purchased-at: uint,
    claim-filed: bool,
    claim-approved: bool,
    claim-amount: uint,
    claim-processed-at: (optional uint)
  }
)

(define-map insurance-policies
  uint
  {
    policy-id: uint,
    distance-factor: uint,
    value-factor: uint,
    reputation-factor: uint,
    final-premium: uint,
    created-at: uint
  }
)

(define-public (create-escrow (merchant principal) (amount uint) (delivery-address (string-ascii 100)))
  (let (
    (escrow-id (+ (var-get escrow-counter) u1))
    (current-block burn-block-height)
  )
    (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set escrows escrow-id {
      customer: tx-sender,
      merchant: merchant,
      amount: amount,
      status: STATUS-PENDING,
      created-at: current-block,
      delivery-address: delivery-address,
      iot-device: none,
      confirmation-hash: none
    })
    
    (var-set escrow-counter escrow-id)
    (var-set total-escrowed (+ (var-get total-escrowed) amount))
    
    (ok escrow-id)
  )
)

(define-public (assign-iot-device (escrow-id uint) (device principal))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
  )
    (asserts! (or (is-eq tx-sender (get merchant escrow)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
    (asserts! (default-to false (get authorized (map-get? iot-devices device))) ERR-UNAUTHORIZED)
    
    (map-set escrows escrow-id (merge escrow {iot-device: (some device)}))
    (ok true)
  )
)

(define-public (confirm-delivery (escrow-id uint) (confirmation-hash (buff 32)))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (iot-device (unwrap! (get iot-device escrow) ERR-UNAUTHORIZED))
  )
    (asserts! (is-eq tx-sender iot-device) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-ALREADY-CONFIRMED)
    
    (map-set escrows escrow-id (merge escrow {
      status: STATUS-CONFIRMED,
      confirmation-hash: (some confirmation-hash)
    }))
    
    (let (
      (device-data (default-to {authorized: false, escrows-confirmed: u0, reputation: u0} (map-get? iot-devices iot-device)))
    )
      (map-set iot-devices iot-device (merge device-data {
        escrows-confirmed: (+ (get escrows-confirmed device-data) u1),
        reputation: (+ (get reputation device-data) u10)
      }))
    )
    
    (ok true)
  )
)

(define-public (release-funds (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (amount (get amount escrow))
    (merchant (get merchant escrow))
  )
    (asserts! (is-eq tx-sender (get customer escrow)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-CONFIRMED) ERR-INVALID-STATUS)
    
    (try! (as-contract (stx-transfer? amount tx-sender merchant)))
    
    (map-set escrows escrow-id (merge escrow {status: STATUS-RELEASED}))
    (var-set total-escrowed (- (var-get total-escrowed) amount))
    
    (let (
      (merchant-data (default-to {name: "", verified: false, total-deliveries: u0, success-rate: u100} (map-get? merchant-profiles merchant)))
    )
      (map-set merchant-profiles merchant (merge merchant-data {
        total-deliveries: (+ (get total-deliveries merchant-data) u1)
      }))
    )
    
    (ok true)
  )
)

(define-public (request-refund (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (amount (get amount escrow))
    (current-block burn-block-height)
    (timeout-block (+ (get created-at escrow) ESCROW-TIMEOUT))
  )
    (asserts! (is-eq tx-sender (get customer escrow)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
    (asserts! (>= current-block timeout-block) ERR-TIMEOUT-NOT-REACHED)
    
    (try! (as-contract (stx-transfer? amount tx-sender (get customer escrow))))
    
    (map-set escrows escrow-id (merge escrow {status: STATUS-REFUNDED}))
    (var-set total-escrowed (- (var-get total-escrowed) amount))
    
    (ok true)
  )
)

(define-public (raise-dispute (escrow-id uint) (reason (string-ascii 200)))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (current-block burn-block-height)
  )
    (asserts! (or (is-eq tx-sender (get customer escrow)) (is-eq tx-sender (get merchant escrow))) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq (get status escrow) STATUS-PENDING) (is-eq (get status escrow) STATUS-CONFIRMED)) ERR-INVALID-STATUS)
    (asserts! (is-none (map-get? disputes escrow-id)) ERR-DISPUTE-EXISTS)
    
    (map-set disputes escrow-id {
      raised-by: tx-sender,
      reason: reason,
      created-at: current-block,
      resolved: false,
      winner: none
    })
    
    (map-set escrows escrow-id (merge escrow {status: STATUS-DISPUTED}))
    (ok true)
  )
)

(define-public (resolve-dispute (escrow-id uint) (winner principal))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (dispute (unwrap! (map-get? disputes escrow-id) ERR-NOT-FOUND))
    (amount (get amount escrow))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-DISPUTED) ERR-INVALID-STATUS)
    (asserts! (not (get resolved dispute)) ERR-ALREADY-RELEASED)
    
    (if (is-eq winner (get customer escrow))
      (try! (as-contract (stx-transfer? amount tx-sender (get customer escrow))))
      (try! (as-contract (stx-transfer? amount tx-sender (get merchant escrow))))
    )
    
    (map-set disputes escrow-id (merge dispute {
      resolved: true,
      winner: (some winner)
    }))
    
    (map-set escrows escrow-id (merge escrow {
      status: (if (is-eq winner (get customer escrow)) STATUS-REFUNDED STATUS-RELEASED)
    }))
    
    (var-set total-escrowed (- (var-get total-escrowed) amount))
    (ok true)
  )
)

(define-public (register-iot-device (device principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set iot-devices device {
      authorized: true,
      escrows-confirmed: u0,
      reputation: u0
    })
    (ok true)
  )
)

(define-public (revoke-iot-device (device principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-delete iot-devices device)
    (ok true)
  )
)

(define-public (register-merchant (name (string-ascii 50)))
  (begin
    (map-set merchant-profiles tx-sender {
      name: name,
      verified: false,
      total-deliveries: u0,
      success-rate: u100
    })
    (ok true)
  )
)

(define-public (verify-merchant (merchant principal))
  (let (
    (merchant-data (unwrap! (map-get? merchant-profiles merchant) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set merchant-profiles merchant (merge merchant-data {verified: true}))
    (ok true)
  )
)

(define-public (initialize-delivery-route (escrow-id uint) (start-lat int) (start-lon int) (end-lat int) (end-lon int))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (distance (calculate-distance start-lat start-lon end-lat end-lon))
    (estimated-time (/ distance u60))
  )
    (asserts! (or (is-eq tx-sender (get merchant escrow)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
    (asserts! (and (>= start-lat -900000000) (<= start-lat 900000000)) ERR-INVALID-COORDINATES)
    (asserts! (and (>= start-lon -1800000000) (<= start-lon 1800000000)) ERR-INVALID-COORDINATES)
    
    (map-set delivery-routes escrow-id {
      start-lat: start-lat,
      start-lon: start-lon,
      end-lat: end-lat,
      end-lon: end-lon,
      estimated-distance: distance,
      estimated-time: estimated-time,
      tracking-active: true,
      waypoint-count: u0
    })
    
    (var-set active-deliveries (+ (var-get active-deliveries) u1))
    (ok true)
  )
)

(define-public (update-drone-location (escrow-id uint) (latitude int) (longitude int) (altitude uint) (speed uint) (battery-level uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (route (unwrap! (map-get? delivery-routes escrow-id) ERR-ROUTE-NOT-FOUND))
    (iot-device (unwrap! (get iot-device escrow) ERR-UNAUTHORIZED))
    (current-waypoint-count (get waypoint-count route))
    (new-waypoint-id (+ current-waypoint-count u1))
  )
    (asserts! (is-eq tx-sender iot-device) ERR-UNAUTHORIZED)
    (asserts! (get tracking-active route) ERR-TRACKING-INACTIVE)
    (asserts! (and (>= latitude -900000000) (<= latitude 900000000)) ERR-INVALID-COORDINATES)
    (asserts! (and (>= longitude -1800000000) (<= longitude 1800000000)) ERR-INVALID-COORDINATES)
    
    (map-set tracking-waypoints {escrow-id: escrow-id, waypoint-id: new-waypoint-id} {
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      timestamp: burn-block-height,
      speed: speed,
      battery-level: battery-level
    })
    
    (map-set delivery-routes escrow-id (merge route {
      waypoint-count: new-waypoint-id
    }))
    
    (var-set total-waypoints (+ (var-get total-waypoints) u1))
    (ok true)
  )
)

(define-public (set-delivery-geofence (escrow-id uint) (center-lat int) (center-lon int) (radius-meters uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get customer escrow)) ERR-UNAUTHORIZED)
    (asserts! (and (>= center-lat -900000000) (<= center-lat 900000000)) ERR-INVALID-COORDINATES)
    (asserts! (and (>= center-lon -1800000000) (<= center-lon 1800000000)) ERR-INVALID-COORDINATES)
    (asserts! (and (> radius-meters u0) (<= radius-meters u10000)) ERR-INVALID-COORDINATES)
    
    (map-set geofence-zones escrow-id {
      center-lat: center-lat,
      center-lon: center-lon,
      radius-meters: radius-meters,
      zone-type: u1,
      active: true
    })
    
    (ok true)
  )
)

(define-public (verify-delivery-location (escrow-id uint) (delivery-lat int) (delivery-lon int))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (geofence (unwrap! (map-get? geofence-zones escrow-id) ERR-GEOFENCE-NOT-SET))
    (iot-device (unwrap! (get iot-device escrow) ERR-UNAUTHORIZED))
    (distance-from-center (calculate-distance delivery-lat delivery-lon (get center-lat geofence) (get center-lon geofence)))
    (within-geofence (<= distance-from-center (get radius-meters geofence)))
  )
    (asserts! (is-eq tx-sender iot-device) ERR-UNAUTHORIZED)
    (asserts! (get active geofence) ERR-GEOFENCE-NOT-SET)
    (asserts! within-geofence ERR-OUTSIDE-GEOFENCE)
    
    (map-set location-verifications escrow-id {
      verified-lat: delivery-lat,
      verified-lon: delivery-lon,
      geofence-validated: within-geofence,
      verification-timestamp: burn-block-height,
      distance-from-target: distance-from-center
    })
    
    (ok true)
  )
)

(define-public (confirm-delivery-with-location (escrow-id uint) (confirmation-hash (buff 32)) (delivery-lat int) (delivery-lon int))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (iot-device (unwrap! (get iot-device escrow) ERR-UNAUTHORIZED))
  )
    (asserts! (is-eq tx-sender iot-device) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-ALREADY-CONFIRMED)
    
    (try! (verify-delivery-location escrow-id delivery-lat delivery-lon))
    
    (map-set escrows escrow-id (merge escrow {
      status: STATUS-CONFIRMED,
      confirmation-hash: (some confirmation-hash)
    }))
    
    (let (
      (device-data (default-to {authorized: false, escrows-confirmed: u0, reputation: u0} (map-get? iot-devices iot-device)))
      (route (map-get? delivery-routes escrow-id))
    )
      (map-set iot-devices iot-device (merge device-data {
        escrows-confirmed: (+ (get escrows-confirmed device-data) u1),
        reputation: (+ (get reputation device-data) u15)
      }))
      
      (match route
        route-data (map-set delivery-routes escrow-id (merge route-data {tracking-active: false}))
        true
      )
    )
    
    (var-set active-deliveries (- (var-get active-deliveries) u1))
    (ok true)
  )
)

(define-public (purchase-delivery-insurance (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (existing-insurance (map-get? delivery-insurance escrow-id))
    (route (map-get? delivery-routes escrow-id))
    (merchant-data (map-get? merchant-profiles (get merchant escrow)))
    (premium (calculate-insurance-premium escrow-id))
  )
    (asserts! (is-eq tx-sender (get customer escrow)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
    (asserts! (is-none existing-insurance) ERR-INSURANCE-ALREADY-PURCHASED)
    (asserts! (> premium u0) ERR-INVALID-ESCROW)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (let (
      (coverage (get amount escrow))
      (risk (calculate-risk-score route merchant-data (get amount escrow)))
    )
      (map-set delivery-insurance escrow-id {
        insured: true,
        premium-paid: premium,
        coverage-amount: coverage,
        risk-score: risk,
        purchased-at: burn-block-height,
        claim-filed: false,
        claim-approved: false,
        claim-amount: u0,
        claim-processed-at: none
      })
      
      (var-set insurance-pool (+ (var-get insurance-pool) premium))
      (ok premium)
    )
  )
)

(define-public (file-insurance-claim (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (insurance (unwrap! (map-get? delivery-insurance escrow-id) ERR-INSURANCE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get customer escrow)) ERR-UNAUTHORIZED)
    (asserts! (get insured insurance) ERR-INSURANCE-NOT-ELIGIBLE)
    (asserts! (not (get claim-filed insurance)) ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (or 
      (is-eq (get status escrow) STATUS-DISPUTED)
      (and (is-eq (get status escrow) STATUS-PENDING) (>= burn-block-height (+ (get created-at escrow) ESCROW-TIMEOUT)))
    ) ERR-INSURANCE-NOT-ELIGIBLE)
    
    (map-set delivery-insurance escrow-id (merge insurance {
      claim-filed: true
    }))
    
    (ok true)
  )
)

(define-public (process-insurance-claim (escrow-id uint) (approved bool))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR-NOT-FOUND))
    (insurance (unwrap! (map-get? delivery-insurance escrow-id) ERR-INSURANCE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (get claim-filed insurance) ERR-INSURANCE-NOT-FOUND)
    (asserts! (is-none (get claim-processed-at insurance)) ERR-CLAIM-ALREADY-PROCESSED)
    
    (if approved
      (let (
        (payout (get coverage-amount insurance))
      )
        (asserts! (>= (var-get insurance-pool) payout) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? payout tx-sender (get customer escrow))))
        
        (map-set delivery-insurance escrow-id (merge insurance {
          claim-approved: true,
          claim-amount: payout,
          claim-processed-at: (some burn-block-height)
        }))
        
        (var-set insurance-pool (- (var-get insurance-pool) payout))
        (var-set total-claims-paid (+ (var-get total-claims-paid) payout))
        (ok payout)
      )
      (begin
        (map-set delivery-insurance escrow-id (merge insurance {
          claim-approved: false,
          claim-processed-at: (some burn-block-height)
        }))
        (ok u0)
      )
    )
  )
)

(define-public (update-base-insurance-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (and (>= new-rate u10) (<= new-rate u200)) ERR-INVALID-ESCROW)
    (var-set base-insurance-rate new-rate)
    (ok new-rate)
  )
)

(define-private (calculate-insurance-premium (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) u0))
    (route (map-get? delivery-routes escrow-id))
    (merchant-data (map-get? merchant-profiles (get merchant escrow)))
    (base-rate (var-get base-insurance-rate))
  )
    (match route
      route-data
        (let (
          (distance-factor (calculate-distance-factor (get estimated-distance route-data)))
          (value-factor (calculate-value-factor (get amount escrow)))
          (reputation-factor (calculate-reputation-factor merchant-data))
          (total-factor (+ (+ distance-factor value-factor) reputation-factor))
        )
          (/ (* (get amount escrow) (* base-rate total-factor)) u100000)
        )
      (/ (* (get amount escrow) base-rate) u1000)
    )
  )
)

(define-private (calculate-risk-score (route (optional {start-lat: int, start-lon: int, end-lat: int, end-lon: int, estimated-distance: uint, estimated-time: uint, tracking-active: bool, waypoint-count: uint})) (merchant (optional {name: (string-ascii 50), verified: bool, total-deliveries: uint, success-rate: uint})) (amount uint))
  (let (
    (distance-risk (match route r (/ (get estimated-distance r) u1000) u50))
    (value-risk (/ amount u10000))
    (merchant-risk (match merchant m (if (get verified m) u10 u30) u50))
  )
    (+ (+ distance-risk value-risk) merchant-risk)
  )
)

(define-private (calculate-distance-factor (distance uint))
  (if (<= distance u5000)
    u100
    (if (<= distance u15000)
      u150
      (if (<= distance u30000)
        u200
        u300
      )
    )
  )
)

(define-private (calculate-value-factor (amount uint))
  (if (<= amount u1000000)
    u100
    (if (<= amount u5000000)
      u120
      (if (<= amount u10000000)
        u150
        u200
      )
    )
  )
)

(define-private (calculate-reputation-factor (merchant-data (optional {name: (string-ascii 50), verified: bool, total-deliveries: uint, success-rate: uint})))
  (match merchant-data
    merchant
      (if (get verified merchant)
        (if (>= (get success-rate merchant) u95)
          u80
          (if (>= (get success-rate merchant) u85)
            u100
            u120
          )
        )
        u150
      )
    u150
  )
)

(define-private (calculate-distance (lat1 int) (lon1 int) (lat2 int) (lon2 int))
  (let (
    (lat-diff (if (> lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
    (lon-diff (if (> lon1 lon2) (- lon1 lon2) (- lon2 lon1)))
    (lat-factor (/ (to-uint (if (< lat-diff 0) (- lat-diff) lat-diff)) u111000))
    (lon-factor (/ (to-uint (if (< lon-diff 0) (- lon-diff) lon-diff)) u111000))
  )
    (+ (* lat-factor lat-factor) (* lon-factor lon-factor))
  )
)

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

(define-read-only (get-iot-device-info (device principal))
  (map-get? iot-devices device)
)

(define-read-only (get-dispute (escrow-id uint))
  (map-get? disputes escrow-id)
)

(define-read-only (get-merchant-profile (merchant principal))
  (map-get? merchant-profiles merchant)
)

(define-read-only (get-contract-stats)
  {
    total-escrows: (var-get escrow-counter),
    total-escrowed: (var-get total-escrowed),
    total-waypoints: (var-get total-waypoints),
    active-deliveries: (var-get active-deliveries),
    insurance-pool: (var-get insurance-pool),
    total-claims-paid: (var-get total-claims-paid),
    base-insurance-rate: (var-get base-insurance-rate),
    contract-owner: CONTRACT-OWNER
  }
)

(define-read-only (is-escrow-expired (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (>= burn-block-height (+ (get created-at escrow) ESCROW-TIMEOUT))
    false
  )
)

(define-read-only (get-escrow-timeout-block (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (some (+ (get created-at escrow) ESCROW-TIMEOUT))
    none
  )
)

(define-read-only (get-delivery-route (escrow-id uint))
  (map-get? delivery-routes escrow-id)
)

(define-read-only (get-drone-waypoint (escrow-id uint) (waypoint-id uint))
  (map-get? tracking-waypoints {escrow-id: escrow-id, waypoint-id: waypoint-id})
)

(define-read-only (get-latest-drone-location (escrow-id uint))
  (match (map-get? delivery-routes escrow-id)
    route (map-get? tracking-waypoints {escrow-id: escrow-id, waypoint-id: (get waypoint-count route)})
    none
  )
)

(define-read-only (get-geofence-zone (escrow-id uint))
  (map-get? geofence-zones escrow-id)
)

(define-read-only (get-location-verification (escrow-id uint))
  (map-get? location-verifications escrow-id)
)

(define-read-only (get-delivery-progress (escrow-id uint))
  (match (map-get? delivery-routes escrow-id)
    route {
      route-initialized: true,
      waypoints-recorded: (get waypoint-count route),
      tracking-active: (get tracking-active route),
      estimated-completion: (+ burn-block-height (get estimated-time route))
    }
    {
      route-initialized: false,
      waypoints-recorded: u0,
      tracking-active: false,
      estimated-completion: u0
    }
  )
)

(define-read-only (is-delivery-in-geofence (escrow-id uint) (lat int) (lon int))
  (match (map-get? geofence-zones escrow-id)
    geofence (let (
      (distance (calculate-distance lat lon (get center-lat geofence) (get center-lon geofence)))
    )
      (<= distance (get radius-meters geofence))
    )
    false
  )
)

(define-read-only (get-tracking-analytics (escrow-id uint))
  (match (map-get? delivery-routes escrow-id)
    route (match (get-latest-drone-location escrow-id)
      latest-location {
        total-waypoints: (get waypoint-count route),
        current-battery: (get battery-level latest-location),
        current-speed: (get speed latest-location),
        current-altitude: (get altitude latest-location),
        last-update: (get timestamp latest-location),
        tracking-status: (get tracking-active route)
      }
      {
        total-waypoints: (get waypoint-count route),
        current-battery: u0,
        current-speed: u0,
        current-altitude: u0,
        last-update: u0,
        tracking-status: (get tracking-active route)
      }
    )
    {
      total-waypoints: u0,
      current-battery: u0,
      current-speed: u0,
      current-altitude: u0,
      last-update: u0,
      tracking-status: false
    }
  )
)

(define-read-only (get-delivery-insurance (escrow-id uint))
  (map-get? delivery-insurance escrow-id)
)

(define-read-only (calculate-insurance-quote (escrow-id uint))
  (ok (calculate-insurance-premium escrow-id))
)

(define-read-only (get-insurance-statistics)
  {
    total-pool: (var-get insurance-pool),
    total-claims-paid: (var-get total-claims-paid),
    base-rate: (var-get base-insurance-rate),
    pool-utilization: (if (> (var-get insurance-pool) u0)
      (/ (* (var-get total-claims-paid) u100) (+ (var-get insurance-pool) (var-get total-claims-paid)))
      u0
    )
  }
)

(define-read-only (is-delivery-insured (escrow-id uint))
  (match (map-get? delivery-insurance escrow-id)
    insurance (get insured insurance)
    false
  )
)
