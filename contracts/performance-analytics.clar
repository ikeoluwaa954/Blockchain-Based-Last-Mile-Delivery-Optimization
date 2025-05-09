;; Performance Analytics Contract
;; Tracks efficiency and service metrics

(define-data-var admin principal tx-sender)

;; Map to store carrier performance metrics
(define-map carrier-metrics principal
  {
    total-deliveries: uint,
    on-time-deliveries: uint,
    average-delivery-time: uint,
    customer-rating: uint,
    last-updated: uint
  }
)

;; Map to store package delivery metrics
(define-map package-metrics uint
  {
    estimated-delivery-time: uint,
    actual-delivery-time: uint,
    on-time: bool,
    customer-rating: (optional uint)
  }
)

;; Public function to record a delivery
(define-public (record-delivery
                (carrier-principal principal)
                (package-id uint)
                (estimated-time uint)
                (actual-time uint))
  (begin
    (asserts! (or (is-eq tx-sender carrier-principal) (is-eq tx-sender (var-get admin))) (err u1)) ;; Only carrier or admin

    ;; Record package metrics
    (map-set package-metrics package-id
      {
        estimated-delivery-time: estimated-time,
        actual-delivery-time: actual-time,
        on-time: (<= actual-time estimated-time),
        customer-rating: none
      }
    )

    ;; Update carrier metrics
    (let ((current-metrics (default-to
                            { total-deliveries: u0, on-time-deliveries: u0, average-delivery-time: u0, customer-rating: u0, last-updated: u0 }
                            (map-get? carrier-metrics carrier-principal)))
          (on-time (<= actual-time estimated-time)))

      (map-set carrier-metrics carrier-principal
        {
          total-deliveries: (+ (get total-deliveries current-metrics) u1),
          on-time-deliveries: (+ (get on-time-deliveries current-metrics) (if on-time u1 u0)),
          average-delivery-time: (/ (+ (* (get average-delivery-time current-metrics) (get total-deliveries current-metrics)) actual-time)
                                   (+ (get total-deliveries current-metrics) u1)),
          customer-rating: (get customer-rating current-metrics),
          last-updated: block-height
        }
      )
    )

    (ok true)
  )
)

;; Public function to submit customer rating
(define-public (submit-rating (package-id uint) (rating uint))
  (begin
    (asserts! (<= rating u5) (err u2)) ;; Rating must be between 0-5
    (asserts! (is-some (map-get? package-metrics package-id)) (err u3)) ;; Package must exist

    (let ((package-metric (unwrap-panic (map-get? package-metrics package-id))))
      (map-set package-metrics package-id
        (merge package-metric { customer-rating: (some rating) })
      )
    )

    (ok true)
  )
)

;; Public function to update carrier rating based on package ratings
(define-public (update-carrier-rating (carrier-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can update
    (asserts! (is-some (map-get? carrier-metrics carrier-principal)) (err u4)) ;; Carrier must exist

    ;; In a real implementation, we would calculate the average rating from all packages
    ;; For simplicity, we're just setting a value

    (let ((current-metrics (unwrap-panic (map-get? carrier-metrics carrier-principal))))
      (map-set carrier-metrics carrier-principal
        (merge current-metrics {
          customer-rating: u4, ;; Example rating (4/5)
          last-updated: block-height
        })
      )
    )

    (ok true)
  )
)

;; Read-only function to get carrier metrics
(define-read-only (get-carrier-metrics (carrier-principal principal))
  (map-get? carrier-metrics carrier-principal)
)

;; Read-only function to get package metrics
(define-read-only (get-package-metrics (package-id uint))
  (map-get? package-metrics package-id)
)

;; Read-only function to calculate on-time delivery percentage
(define-read-only (get-on-time-percentage (carrier-principal principal))
  (let ((metrics (default-to
                  { total-deliveries: u0, on-time-deliveries: u0, average-delivery-time: u0, customer-rating: u0, last-updated: u0 }
                  (map-get? carrier-metrics carrier-principal))))
    (if (is-eq (get total-deliveries metrics) u0)
      u0
      (/ (* (get on-time-deliveries metrics) u100) (get total-deliveries metrics))
    )
  )
)
