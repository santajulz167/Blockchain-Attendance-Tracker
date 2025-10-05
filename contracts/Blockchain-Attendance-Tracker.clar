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

(define-constant ERR_INVALID_PERIOD (err u106))
(define-constant ERR_INSUFFICIENT_DATA (err u107))

(define-constant ERR_EXCUSE_NOT_FOUND (err u108))
(define-constant ERR_EXCUSE_ALREADY_PROCESSED (err u109))
(define-constant ERR_EXCUSE_ALREADY_SUBMITTED (err u110))

(define-constant ERR_INSUFFICIENT_POINTS (err u111))
(define-constant ERR_INVALID_AMOUNT (err u112))

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


(define-map user-analytics
  { user-id: principal, period: uint }
  {
    total-expected-days: uint,
    total-present-days: uint,
    total-absent-days: uint,
    attendance-rate: uint,
    period-start: uint,
    period-end: uint
  }
)

(define-map weekly-analytics
  { week-number: uint, year: uint }
  {
    total-users: uint,
    average-attendance-rate: uint,
    peak-attendance-day: uint,
    total-check-ins: uint,
    total-check-outs: uint
  }
)

(define-public (calculate-user-analytics (user principal) (start-date uint) (end-date uint))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: user }) ERR_USER_NOT_FOUND))
      (period-key (+ (* start-date u1000) end-date))
      (analytics-data (calculate-period-analytics user start-date end-date))
    )
    (begin
      (asserts! (> end-date start-date) ERR_INVALID_PERIOD)
      (asserts! (get is-active user-data) ERR_UNAUTHORIZED)
      (map-set user-analytics
        { user-id: user, period: period-key }
        analytics-data
      )
      (ok analytics-data)
    )
  )
)

(define-public (generate-weekly-analytics (week-number uint) (year uint))
  (let
    (
      (total-users-count (var-get total-registered-users))
      (week-analytics (calculate-weekly-stats week-number year))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (and (> week-number u0) (<= week-number u53)) ERR_INVALID_PERIOD)
      (asserts! (> total-users-count u0) ERR_INSUFFICIENT_DATA)
      (map-set weekly-analytics
        { week-number: week-number, year: year }
        week-analytics
      )
      (ok week-analytics)
    )
  )
)

(define-private (calculate-period-analytics (user principal) (start-date uint) (end-date uint))
  (let
    (
      (expected-days (+ (- end-date start-date) u1))
      (present-days (count-user-attendance user start-date end-date))
      (absent-days (- expected-days present-days))
      (attendance-rate (if (> expected-days u0) (/ (* present-days u100) expected-days) u0))
    )
    {
      total-expected-days: expected-days,
      total-present-days: present-days,
      total-absent-days: absent-days,
      attendance-rate: attendance-rate,
      period-start: start-date,
      period-end: end-date
    }
  )
)

(define-private (calculate-weekly-stats (week-number uint) (year uint))
  {
    total-users: (var-get total-registered-users),
    average-attendance-rate: (calculate-average-attendance-rate week-number),
    peak-attendance-day: week-number,
    total-check-ins: (* week-number u7),
    total-check-outs: (* week-number u6)
  }
)

(define-private (count-user-attendance (user principal) (start-date uint) (end-date uint))
  (fold count-attendance-days (list start-date (+ start-date u1) (+ start-date u2) (+ start-date u3) (+ start-date u4)) u0)
)

(define-private (count-attendance-days (date uint) (accumulated-count uint))
  (if (is-some (map-get? attendance-records { user-id: tx-sender, date: date }))
    (+ accumulated-count u1)
    accumulated-count
  )
)

(define-private (calculate-average-attendance-rate (week-number uint))
  (if (> week-number u0) (/ (* week-number u85) u1) u75)
)

(define-read-only (get-user-analytics (user principal) (start-date uint) (end-date uint))
  (let
    (
      (period-key (+ (* start-date u1000) end-date))
    )
    (map-get? user-analytics { user-id: user, period: period-key })
  )
)

(define-read-only (get-weekly-analytics (week-number uint) (year uint))
  (map-get? weekly-analytics { week-number: week-number, year: year })
)

(define-read-only (get-user-attendance-summary (user principal))
  (let
    (
      (user-data (map-get? users { user-id: user }))
      (streak-data (map-get? user-streaks { user-id: user }))
    )
    (match user-data
      data (ok {
        total-days: (get total-days data),
        current-streak: (match streak-data streak-info (get current-streak streak-info) u0),
        max-streak: (match streak-data streak-info (get max-streak streak-info) u0),
        is-active: (get is-active data)
      })
      ERR_USER_NOT_FOUND
    )
  )
)

(define-map excuse-requests
  { user-id: principal, date: uint }
  {
    reason: (string-ascii 200),
    submitted-block: uint,
    status: (string-ascii 10),
    admin-notes: (optional (string-ascii 100))
  }
)

(define-map excuse-history
  { user-id: principal }
  {
    total-submitted: uint,
    total-approved: uint,
    total-denied: uint
  }
)

(define-public (submit-excuse-request (date uint) (reason (string-ascii 200)))
  (let
    (
      (user-data (unwrap! (map-get? users { user-id: tx-sender }) ERR_USER_NOT_FOUND))
      (existing-request (map-get? excuse-requests { user-id: tx-sender, date: date }))
      (current-history (default-to
        { total-submitted: u0, total-approved: u0, total-denied: u0 }
        (map-get? excuse-history { user-id: tx-sender })
      ))
    )
    (begin
      (asserts! (get is-active user-data) ERR_UNAUTHORIZED)
      (asserts! (> date u0) ERR_INVALID_DATE)
      (asserts! (is-none existing-request) ERR_EXCUSE_ALREADY_SUBMITTED)
      (map-set excuse-requests
        { user-id: tx-sender, date: date }
        {
          reason: reason,
          submitted-block: stacks-block-height,
          status: "pending",
          admin-notes: none
        }
      )
      (map-set excuse-history
        { user-id: tx-sender }
        (merge current-history { total-submitted: (+ (get total-submitted current-history) u1) })
      )
      (ok true)
    )
  )
)

(define-public (approve-excuse (user principal) (date uint) (admin-notes (optional (string-ascii 100))))
  (let
    (
      (excuse-request (unwrap! (map-get? excuse-requests { user-id: user, date: date }) ERR_EXCUSE_NOT_FOUND))
      (current-history (default-to
        { total-submitted: u0, total-approved: u0, total-denied: u0 }
        (map-get? excuse-history { user-id: user })
      ))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status excuse-request) "pending") ERR_EXCUSE_ALREADY_PROCESSED)
      (map-set excuse-requests
        { user-id: user, date: date }
        (merge excuse-request { status: "approved", admin-notes: admin-notes })
      )
      (map-set excuse-history
        { user-id: user }
        (merge current-history { total-approved: (+ (get total-approved current-history) u1) })
      )
      (ok true)
    )
  )
)

(define-public (deny-excuse (user principal) (date uint) (admin-notes (optional (string-ascii 100))))
  (let
    (
      (excuse-request (unwrap! (map-get? excuse-requests { user-id: user, date: date }) ERR_EXCUSE_NOT_FOUND))
      (current-history (default-to
        { total-submitted: u0, total-approved: u0, total-denied: u0 }
        (map-get? excuse-history { user-id: user })
      ))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status excuse-request) "pending") ERR_EXCUSE_ALREADY_PROCESSED)
      (map-set excuse-requests
        { user-id: user, date: date }
        (merge excuse-request { status: "denied", admin-notes: admin-notes })
      )
      (map-set excuse-history
        { user-id: user }
        (merge current-history { total-denied: (+ (get total-denied current-history) u1) })
      )
      (ok true)
    )
  )
)

(define-read-only (get-excuse-request (user principal) (date uint))
  (map-get? excuse-requests { user-id: user, date: date })
)

(define-read-only (get-excuse-history (user principal))
  (map-get? excuse-history { user-id: user })
)

(define-map user-reputation
  { user-id: principal }
  {
    current-points: uint,
    total-earned: uint,
    total-redeemed: uint,
    last-reward-block: uint
  }
)

(define-map reputation-config
  { config-key: (string-ascii 20) }
  { multiplier: uint }
)

(define-data-var total-points-distributed uint u0)
(define-data-var base-reward-points uint u10)

(define-public (configure-reward-multiplier (config-key (string-ascii 20)) (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> multiplier u0) ERR_INVALID_AMOUNT)
    (map-set reputation-config
      { config-key: config-key }
      { multiplier: multiplier }
    )
    (ok true)
  )
)

(define-public (redeem-reputation-points (amount uint))
  (let
    (
      (reputation-data (default-to
        { current-points: u0, total-earned: u0, total-redeemed: u0, last-reward-block: u0 }
        (map-get? user-reputation { user-id: tx-sender })
      ))
    )
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (>= (get current-points reputation-data) amount) ERR_INSUFFICIENT_POINTS)
      (map-set user-reputation
        { user-id: tx-sender }
        (merge reputation-data {
          current-points: (- (get current-points reputation-data) amount),
          total-redeemed: (+ (get total-redeemed reputation-data) amount)
        })
      )
      (ok true)
    )
  )
)

(define-private (award-reputation-points (user principal))
  (let
    (
      (reputation-data (default-to
        { current-points: u0, total-earned: u0, total-redeemed: u0, last-reward-block: u0 }
        (map-get? user-reputation { user-id: user })
      ))
      (points-to-award (var-get base-reward-points))
    )
    (begin
      (map-set user-reputation
        { user-id: user }
        {
          current-points: (+ (get current-points reputation-data) points-to-award),
          total-earned: (+ (get total-earned reputation-data) points-to-award),
          total-redeemed: (get total-redeemed reputation-data),
          last-reward-block: stacks-block-height
        }
      )
      (var-set total-points-distributed (+ (var-get total-points-distributed) points-to-award))
    )
  )
)

(define-read-only (get-reputation-balance (user principal))
  (map-get? user-reputation { user-id: user })
)

(define-read-only (get-total-points-distributed)
  (ok (var-get total-points-distributed))
)