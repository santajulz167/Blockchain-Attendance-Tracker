(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_CHECKED_IN (err u101))
(define-constant ERR_NOT_CHECKED_IN (err u102))
(define-constant ERR_INVALID_DATE (err u103))
(define-constant ERR_USER_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ACHIEVEMENT_PERFECT_WEEK "perfect-week")
(define-constant ACHIEVEMENT_PERFECT_MONTH "perfect-month")
(define-constant ACHIEVEMENT_STREAK_10 "streak-10")
(define-constant ACHIEVEMENT_STREAK_30 "streak-30")
(define-constant ACHIEVEMENT_VETERAN_100 "veteran-100")

(define-map users
  { user-id: principal }
  {
    name: (string-ascii 50),
    role: (string-ascii 20),
    is-active: bool,
    total-days: uint,
    registration-block: uint
  }
)

(define-map attendance-records
  { user-id: principal, date: uint }
  {
    check-in-time: uint,
    check-out-time: (optional uint),
    status: (string-ascii 10),
    notes: (optional (string-ascii 100))
  }
)

(define-map daily-stats
  { date: uint }
  {
    total-check-ins: uint,
    total-check-outs: uint,
    active-users: uint
  }
)

(define-data-var total-registered-users uint u0)
(define-data-var contract-active bool true)

(define-public (register-user (user principal) (name (string-ascii 50)) (role (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? users { user-id: user })) ERR_ALREADY_REGISTERED)
    (map-set users
      { user-id: user }
      {
        name: name,
        role: role,
        is-active: true,
        total-days: u0,
        registration-block: stacks-block-height
      }
    )
    (var-set total-registered-users (+ (var-get total-registered-users) u1))
    (ok true)
  )
)

(define-public (check-in (date uint))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: tx-sender }) ERR_USER_NOT_FOUND))
      (existing-record (map-get? attendance-records { user-id: tx-sender, date: date }))
    )
    (begin
      (asserts! (get is-active user-data) ERR_UNAUTHORIZED)
      (asserts! (> date u0) ERR_INVALID_DATE)
      (asserts! (is-none existing-record) ERR_ALREADY_CHECKED_IN)
      (map-set attendance-records
        { user-id: tx-sender, date: date }
        {
          check-in-time: stacks-block-height,
          check-out-time: none,
          status: "present",
          notes: none
        }
      )
      (map-set users
        { user-id: tx-sender }
        (merge user-data { total-days: (+ (get total-days user-data) u1) })
      )
      (update-daily-stats date "check-in")
      (ok true)
    )
  )
)

(define-public (check-out (date uint) (notes (optional (string-ascii 100))))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: tx-sender }) ERR_USER_NOT_FOUND))
      (attendance-record (unwrap! (map-get? attendance-records { user-id: tx-sender, date: date }) ERR_NOT_CHECKED_IN))
    )
    (begin
      (asserts! (get is-active user-data) ERR_UNAUTHORIZED)
      (asserts! (is-none (get check-out-time attendance-record)) ERR_ALREADY_CHECKED_IN)
      (map-set attendance-records
        { user-id: tx-sender, date: date }
        (merge attendance-record {
          check-out-time: (some stacks-block-height),
          notes: notes
        })
      )
      (update-daily-stats date "check-out")
      (ok true)
    )
  )
)

(define-public (mark-absent (user principal) (date uint) (notes (optional (string-ascii 100))))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user }) ERR_USER_NOT_FOUND))
      (existing-record (map-get? attendance-records { user-id: user, date: date }))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (get is-active user-data) ERR_UNAUTHORIZED)
      (asserts! (> date u0) ERR_INVALID_DATE)
      (asserts! (is-none existing-record) ERR_ALREADY_CHECKED_IN)
      (map-set attendance-records
        { user-id: user, date: date }
        {
          check-in-time: u0,
          check-out-time: none,
          status: "absent",
          notes: notes
        }
      )
      (ok true)
    )
  )
)

(define-public (deactivate-user (user principal))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user }) ERR_USER_NOT_FOUND))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (map-set users
        { user-id: user }
        (merge user-data { is-active: false })
      )
      (ok true)
    )
  )
)

(define-public (reactivate-user (user principal))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user }) ERR_USER_NOT_FOUND))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (map-set users
        { user-id: user }
        (merge user-data { is-active: true })
      )
      (ok true)
    )
  )
)

(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

(define-private (update-daily-stats (date uint) (action (string-ascii 10)))
  (let
    (
      (current-stats (default-to
        { total-check-ins: u0, total-check-outs: u0, active-users: u0 }
        (map-get? daily-stats { date: date })
      ))
    )
    (if (is-eq action "check-in")
      (map-set daily-stats
        { date: date }
        (merge current-stats {
          total-check-ins: (+ (get total-check-ins current-stats) u1),
          active-users: (+ (get active-users current-stats) u1)
        })
      )
      (map-set daily-stats
        { date: date }
        (merge current-stats {
          total-check-outs: (+ (get total-check-outs current-stats) u1)
        })
      )
    )
  )
)

(define-read-only (get-user-info (user principal))
  (map-get? users { user-id: user })
)

(define-read-only (get-attendance-record (user principal) (date uint))
  (map-get? attendance-records { user-id: user, date: date })
)

(define-read-only (get-daily-stats (date uint))
  (map-get? daily-stats { date: date })
)

(define-read-only (get-user-attendance-count (user principal))
  (match (map-get? users { user-id: user })
    user-data (ok (get total-days user-data))
    ERR_USER_NOT_FOUND
  )
)

(define-read-only (is-user-active (user principal))
  (match (map-get? users { user-id: user })
    user-data (ok (get is-active user-data))
    ERR_USER_NOT_FOUND
  )
)

(define-read-only (get-total-registered-users)
  (ok (var-get total-registered-users))
)

(define-read-only (is-contract-active)
  (ok (var-get contract-active))
)

(define-read-only (get-contract-owner)
  (ok CONTRACT_OWNER)
)



(define-map user-achievements
  { user-id: principal, achievement-id: (string-ascii 20) }
  {
    earned-date: uint,
    earned-block: uint,
    achievement-name: (string-ascii 50)
  }
)

(define-map user-streaks
  { user-id: principal }
  {
    current-streak: uint,
    last-attendance-date: uint,
    max-streak: uint
  }
)

(define-private (check-and-award-achievements (user principal) (current-date uint))
  (let
    (
      (user-data (unwrap-panic (map-get? users { user-id: user })))
      (current-streak-data (default-to 
        { current-streak: u0, last-attendance-date: u0, max-streak: u0 }
        (map-get? user-streaks { user-id: user })))
    )
    (begin
      (update-user-streak user current-date current-streak-data)
      (award-streak-achievements user current-streak-data)
      (award-total-days-achievements user (get total-days user-data))
    )
  )
)

(define-private (update-user-streak (user principal) (current-date uint) (streak-data { current-streak: uint, last-attendance-date: uint, max-streak: uint }))
  (let
    (
      (is-consecutive (is-eq (get last-attendance-date streak-data) (- current-date u1)))
      (new-streak (if is-consecutive (+ (get current-streak streak-data) u1) u1))
      (new-max-streak (if (> new-streak (get max-streak streak-data)) new-streak (get max-streak streak-data)))
    )
    (map-set user-streaks
      { user-id: user }
      {
        current-streak: new-streak,
        last-attendance-date: current-date,
        max-streak: new-max-streak
      }
    )
  )
)

(define-private (award-streak-achievements (user principal) (streak-data { current-streak: uint, last-attendance-date: uint, max-streak: uint }))
  (begin
    (if (and (>= (get current-streak streak-data) u10) (is-none (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_STREAK_10 })))
      (map-set user-achievements
        { user-id: user, achievement-id: ACHIEVEMENT_STREAK_10 }
        { earned-date: (get last-attendance-date streak-data), earned-block: stacks-block-height, achievement-name: "10-Day Streak Champion" }
      )
      true
    )
    (if (and (>= (get current-streak streak-data) u30) (is-none (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_STREAK_30 })))
      (map-set user-achievements
        { user-id: user, achievement-id: ACHIEVEMENT_STREAK_30 }
        { earned-date: (get last-attendance-date streak-data), earned-block: stacks-block-height, achievement-name: "30-Day Streak Legend" }
      )
      true
    )
  )
)

(define-private (award-total-days-achievements (user principal) (total-days uint))
  (if (and (>= total-days u100) (is-none (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_VETERAN_100 })))
    (map-set user-achievements
      { user-id: user, achievement-id: ACHIEVEMENT_VETERAN_100 }
      { earned-date: u0, earned-block: stacks-block-height, achievement-name: "100-Day Veteran" }
    )
    true
  )
)

(define-read-only (get-user-achievements (user principal))
  (list
    (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_PERFECT_WEEK })
    (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_PERFECT_MONTH })
    (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_STREAK_10 })
    (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_STREAK_30 })
    (map-get? user-achievements { user-id: user, achievement-id: ACHIEVEMENT_VETERAN_100 })
  )
)

(define-read-only (get-user-streak (user principal))
  (map-get? user-streaks { user-id: user })
)

(define-read-only (has-achievement (user principal) (achievement-id (string-ascii 20)))
  (is-some (map-get? user-achievements { user-id: user, achievement-id: achievement-id }))
)