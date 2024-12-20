;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-pair (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-not-initialized (err u104))
(define-constant err-already-initialized (err u105))

;; Data Maps
(define-map pairs 
    { pair-id: uint }
    { base: (string-ascii 10),
      quote: (string-ascii 10),
      price: uint,
      supply: uint,
      last-rebase: uint })

(define-map user-balances
    { user: principal, pair-id: uint }
    { balance: uint })

(define-map price-feeds
    { pair-id: uint }
    { price: uint,
      timestamp: uint,
      valid: bool })

(define-map governance-params
    { param-id: uint }
    { value: uint,
      last-update: uint })

;; Variables
(define-data-var next-pair-id uint u1)
(define-data-var rebase-threshold uint u100) ;; 1% deviation threshold
(define-data-var min-collateral-ratio uint u1500) ;; 150%
(define-data-var protocol-fee uint u25) ;; 0.25%

;; Read-only functions
(define-read-only (get-pair-details (pair-id uint))
    (map-get? pairs {pair-id: pair-id}))

(define-read-only (get-user-balance (user principal) (pair-id uint))
    (default-to
        {balance: u0}
        (map-get? user-balances {user: user, pair-id: pair-id})))

(define-read-only (get-price (pair-id uint))
    (match (map-get? price-feeds {pair-id: pair-id})
        price-data (ok (get price price-data))
        (err err-invalid-pair)))

;; Governance functions
(define-public (update-governance-param (param-id uint) (new-value uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set governance-params
            {param-id: param-id}
            {value: new-value, last-update: block-height}))))

;; Core functionality
(define-public (create-forex-pair (base (string-ascii 10)) (quote (string-ascii 10)) (initial-price uint))
    (let ((pair-id (var-get next-pair-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set pairs
            {pair-id: pair-id}
            {base: base,
             quote: quote,
             price: initial-price,
             supply: u0,
             last-rebase: block-height})
        (var-set next-pair-id (+ pair-id u1))
        (ok pair-id)))

(define-public (mint-synthetic (pair-id uint) (amount uint))
    (let ((current-price (unwrap! (get-price pair-id) err-invalid-price))
          (required-collateral (* amount (/ current-price u100000000)))
          (user-balance (stx-get-balance tx-sender)))
        (asserts! (>= user-balance required-collateral) err-insufficient-balance)
        (try! (stx-transfer? required-collateral tx-sender (as-contract tx-sender)))
        (match (map-get? pairs {pair-id: pair-id})
            pair-data
            (begin
                (map-set pairs
                    {pair-id: pair-id}
                    (merge pair-data {supply: (+ (get supply pair-data) amount)}))
                (map-set user-balances
                    {user: tx-sender, pair-id: pair-id}
                    {balance: (+ amount (get balance (get-user-balance tx-sender pair-id)))})
                (ok true))
            err-invalid-pair)))

(define-public (burn-synthetic (pair-id uint) (amount uint))
    (let ((user-data (get-user-balance tx-sender pair-id)))
        (asserts! (>= (get balance user-data) amount) err-insufficient-balance)
        (match (map-get? pairs {pair-id: pair-id})
            pair-data
            (begin
                (map-set pairs
                    {pair-id: pair-id}
                    (merge pair-data {supply: (- (get supply pair-data) amount)}))
                (map-set user-balances
                    {user: tx-sender, pair-id: pair-id}
                    {balance: (- (get balance user-data) amount)})
                (ok true))
            err-invalid-pair)))

;; AMM Functions
(define-public (swap (from-pair uint) (to-pair uint) (amount uint))
    (let ((from-balance (get balance (get-user-balance tx-sender from-pair)))
          (from-price (unwrap! (get-price from-pair) err-invalid-price))
          (to-price (unwrap! (get-price to-pair) err-invalid-price)))
        (asserts! (>= from-balance amount) err-insufficient-balance)
        (let ((output-amount (/ (* amount from-price) to-price))
              (fee (/ (* output-amount (var-get protocol-fee)) u10000)))
            (try! (burn-synthetic from-pair amount))
            (try! (mint-synthetic to-pair (- output-amount fee)))
            (ok {output: (- output-amount fee), fee: fee}))))

;; Rebase Mechanism
(define-public (trigger-rebase (pair-id uint))
    (let ((pair-data (unwrap! (map-get? pairs {pair-id: pair-id}) err-invalid-pair))
          (current-price (unwrap! (get-price pair-id) err-invalid-price))
          (target-price (get price pair-data))
          (price-diff (if (> current-price target-price)
                         (- current-price target-price)
                         (- target-price current-price)))
          (deviation (* price-diff u10000)))
        (asserts! (> deviation (var-get rebase-threshold)) (ok false))
        (let ((new-supply (/ (* (get supply pair-data) target-price) current-price)))
            (map-set pairs
                {pair-id: pair-id}
                (merge pair-data 
                    {supply: new-supply,
                     last-rebase: block-height}))
            (ok true))))

;; Oracle Interface
(define-public (update-price-feed (pair-id uint) (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set price-feeds
            {pair-id: pair-id}
            {price: new-price,
             timestamp: block-height,
             valid: true})
        (ok true)))

;; Emergency Functions
(define-public (pause-trading)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (resume-trading)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))