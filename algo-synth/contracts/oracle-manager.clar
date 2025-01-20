;; Oracle Manager Contract
;; Manages price feeds for the forex trading system with multiple data sources and safety checks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-invalid-oracle (err u201))
(define-constant err-stale-price (err u202))
(define-constant err-price-deviation (err u203))
(define-constant err-oracle-disabled (err u204))
(define-constant err-invalid-price (err u205))

;; Price validity duration (in blocks)
(define-data-var price-valid-duration uint u150)  ;; ~15 minutes at 6s block time

;; Maximum allowed deviation between oracle sources (in basis points)
(define-data-var max-price-deviation uint u500)   ;; 5% max deviation

;; Data Maps and Variables
(define-map oracle-sources
    { oracle-id: uint }
    { name: (string-ascii 20),
      enabled: bool,
      trusted: bool,
      last-update: uint })

(define-map price-feeds
    { pair-id: uint, oracle-id: uint }
    { price: uint,
      timestamp: uint,
      confidence: uint })      ;; Confidence score out of 10000

(define-map aggregated-prices
    { pair-id: uint }
    { price: uint,
      timestamp: uint,
      source-count: uint })

(define-data-var next-oracle-id uint u1)

;; Read-only functions
(define-read-only (get-oracle-details (oracle-id uint))
    (map-get? oracle-sources {oracle-id: oracle-id}))

(define-read-only (get-price-feed (pair-id uint) (oracle-id uint))
    (map-get? price-feeds {pair-id: pair-id, oracle-id: oracle-id}))

(define-read-only (get-aggregated-price (pair-id uint))
    (map-get? aggregated-prices {pair-id: pair-id}))

(define-read-only (is-price-valid (timestamp uint))
    (let ((current-height block-height)
          (max-age (var-get price-valid-duration)))
        (>= (+ timestamp max-age) current-height)))

;; Oracle Management Functions
(define-public (register-oracle (name (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((oracle-id (var-get next-oracle-id)))
            (map-set oracle-sources
                {oracle-id: oracle-id}
                {name: name,
                 enabled: true,
                 trusted: true,
                 last-update: block-height})
            (var-set next-oracle-id (+ oracle-id u1))
            (ok oracle-id))))

(define-public (toggle-oracle (oracle-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? oracle-sources {oracle-id: oracle-id})
            oracle-data (ok (map-set oracle-sources
                            {oracle-id: oracle-id}
                            (merge oracle-data 
                                  {enabled: (not (get enabled oracle-data))})))
            err-invalid-oracle)))

;; Price Feed Functions
(define-public (submit-price (pair-id uint) (oracle-id uint) (price uint) (confidence uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? oracle-sources {oracle-id: oracle-id})) err-invalid-oracle)
        (asserts! (get enabled (unwrap! (map-get? oracle-sources {oracle-id: oracle-id}) err-invalid-oracle)) err-oracle-disabled)
        (asserts! (and (> price u0) (<= confidence u10000)) err-invalid-price)
        
        ;; Update price feed
        (map-set price-feeds
            {pair-id: pair-id, oracle-id: oracle-id}
            {price: price,
             timestamp: block-height,
             confidence: confidence})
        
        ;; Update oracle last-update timestamp
        (map-set oracle-sources
            {oracle-id: oracle-id}
            (merge (unwrap! (map-get? oracle-sources {oracle-id: oracle-id}) err-invalid-oracle)
                  {last-update: block-height}))
        
        ;; Trigger price aggregation
        (try! (aggregate-prices pair-id))
        (ok true)))

;; Price Aggregation
(define-private (aggregate-prices (pair-id uint))
    (let ((valid-prices (filter-valid-prices pair-id)))
        (if (> (len valid-prices) u0)
            (let ((weighted-avg (calculate-weighted-average valid-prices)))
                (map-set aggregated-prices
                    {pair-id: pair-id}
                    {price: weighted-avg,
                     timestamp: block-height,
                     source-count: (len valid-prices)})
                (ok true))
            (ok false))))

(define-private (filter-valid-prices (pair-id uint))
    (filter is-valid-price-tuple
        (map unwrap-price
            (get-all-oracle-prices pair-id))))

(define-private (is-valid-price-tuple (price-tuple {price: uint, timestamp: uint, confidence: uint}))
    (and
        (> (get price price-tuple) u0)
        (is-price-valid (get timestamp price-tuple))
        (> (get confidence price-tuple) u5000)))  ;; Minimum 50% confidence required

(define-private (calculate-weighted-average (prices (list 100 {price: uint, timestamp: uint, confidence: uint})))
    (let ((sum-products (fold + u0 (map weighted-price prices)))
          (sum-weights (fold + u0 (map get-confidence prices))))
        (/ (* sum-products u100000000) sum-weights)))

(define-private (weighted-price (price-tuple {price: uint, timestamp: uint, confidence: uint}))
    (* (get price price-tuple) (get confidence price-tuple)))

(define-private (get-confidence (price-tuple {price: uint, timestamp: uint, confidence: uint}))
    (get confidence price-tuple))

;; Helper functions
(define-private (get-all-oracle-prices (pair-id uint))
    (map unwrap-or-default
        (map get-oracle-price
            (get-active-oracle-ids))))

(define-private (get-oracle-price (oracle-id uint))
    (map-get? price-feeds {pair-id: pair-id, oracle-id: oracle-id}))

(define-private (unwrap-or-default (price-opt (optional {price: uint, timestamp: uint, confidence: uint})))
    (match price-opt
        price-data price-data
        {price: u0, timestamp: u0, confidence: u0}))

(define-private (get-active-oracle-ids)
    (filter get-enabled
        (map to-uint (list u1 u2 u3 u4 u5))))  ;; Support up to 5 oracles

(define-private (get-enabled (oracle-id uint))
    (match (map-get? oracle-sources {oracle-id: oracle-id})
        oracle-data (get enabled oracle-data)
        false))

(define-private (to-uint (n uint)) n)