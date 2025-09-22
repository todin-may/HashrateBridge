
;; title: HashrateBridge
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool for Bitcoin hashrate tokens and STX
;; description: An automated market maker (AMM) that enables swapping between Bitcoin hashrate tokens and STX tokens with liquidity provision rewards

;; traits
;; Note: SIP-010 trait not needed for current implementation using built-in fungible tokens

;; token definitions
;; We'll use a simple fungible token for the hashrate token representation
(define-fungible-token hashrate-token)
(define-fungible-token lp-token)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-insufficient-liquidity (err u102))
(define-constant err-slippage-too-high (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-pool-not-initialized (err u105))
(define-constant err-already-initialized (err u106))
(define-constant err-zero-amount (err u107))

;; Minimum liquidity to prevent division by zero
(define-constant minimum-liquidity u1000)

;; Fee rate (0.3% = 30 basis points out of 10000)
(define-constant fee-rate u30)
(define-constant fee-denominator u10000)

;; data vars
(define-data-var pool-initialized bool false)
(define-data-var total-lp-supply uint u0)
(define-data-var stx-reserve uint u0)
(define-data-var hashrate-reserve uint u0)
(define-data-var fee-to principal contract-owner)

;; data maps
(define-map user-lp-balances principal uint)
(define-map user-hashrate-balances principal uint)

;; Helper function to approximate square root (non-recursive)
(define-private (approx-sqrt (x uint))
  (if (<= x u1)
    x
    (let ((guess (/ x u2)))
      (let ((better-guess (/ (+ guess (/ x guess)) u2)))
        (let ((even-better (/ (+ better-guess (/ x better-guess)) u2)))
          even-better)))))

;; Initialize the liquidity pool
(define-public (initialize-pool (initial-stx uint) (initial-hashrate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get pool-initialized)) err-already-initialized)
    (asserts! (> initial-stx u0) err-zero-amount)
    (asserts! (> initial-hashrate u0) err-zero-amount)

    ;; Transfer STX from caller
    (try! (stx-transfer? initial-stx tx-sender (as-contract tx-sender)))

    ;; Mint initial hashrate tokens to the pool
    (try! (ft-mint? hashrate-token initial-hashrate (as-contract tx-sender)))

    ;; Calculate initial LP tokens (geometric mean)
    (let ((initial-liquidity (approx-sqrt (* initial-stx initial-hashrate))))
      ;; Burn minimum liquidity to prevent manipulation
      (try! (ft-mint? lp-token minimum-liquidity (as-contract tx-sender)))

      ;; Mint LP tokens to provider
      (let ((lp-amount (- initial-liquidity minimum-liquidity)))
        (try! (ft-mint? lp-token lp-amount tx-sender))
        (map-set user-lp-balances tx-sender lp-amount)

        ;; Update reserves and state
        (var-set stx-reserve initial-stx)
        (var-set hashrate-reserve initial-hashrate)
        (var-set total-lp-supply initial-liquidity)
        (var-set pool-initialized true)

        (ok lp-amount)))))

;; Add liquidity to the pool
(define-public (add-liquidity (stx-amount uint) (hashrate-amount uint) (min-lp-tokens uint))
  (begin
    (asserts! (var-get pool-initialized) err-pool-not-initialized)
    (asserts! (> stx-amount u0) err-zero-amount)
    (asserts! (> hashrate-amount u0) err-zero-amount)

    (let (
      (current-stx-reserve (var-get stx-reserve))
      (current-hashrate-reserve (var-get hashrate-reserve))
      (current-lp-supply (var-get total-lp-supply))
      (stx-liquidity (/ (* stx-amount current-lp-supply) current-stx-reserve))
      (hashrate-liquidity (/ (* hashrate-amount current-lp-supply) current-hashrate-reserve))
      (lp-tokens (if (< stx-liquidity hashrate-liquidity) stx-liquidity hashrate-liquidity))
    )
      (asserts! (>= lp-tokens min-lp-tokens) err-slippage-too-high)

      ;; Transfer STX from user
      (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))

      ;; Mint hashrate tokens to user first, then transfer to pool
      (try! (ft-mint? hashrate-token hashrate-amount tx-sender))
      (try! (as-contract (ft-transfer? hashrate-token hashrate-amount tx-sender (as-contract tx-sender))))

      ;; Mint LP tokens to user
      (try! (ft-mint? lp-token lp-tokens tx-sender))

      ;; Update user LP balance
      (let ((current-balance (default-to u0 (map-get? user-lp-balances tx-sender))))
        (map-set user-lp-balances tx-sender (+ current-balance lp-tokens)))

      ;; Update reserves
      (var-set stx-reserve (+ current-stx-reserve stx-amount))
      (var-set hashrate-reserve (+ current-hashrate-reserve hashrate-amount))
      (var-set total-lp-supply (+ current-lp-supply lp-tokens))

      (ok lp-tokens))))

;; Remove liquidity from the pool
(define-public (remove-liquidity (lp-amount uint) (min-stx uint) (min-hashrate uint))
  (begin
    (asserts! (var-get pool-initialized) err-pool-not-initialized)
    (asserts! (> lp-amount u0) err-zero-amount)

    (let (
      (current-stx-reserve (var-get stx-reserve))
      (current-hashrate-reserve (var-get hashrate-reserve))
      (current-lp-supply (var-get total-lp-supply))
      (user-balance (default-to u0 (map-get? user-lp-balances tx-sender)))
      (stx-amount (/ (* lp-amount current-stx-reserve) current-lp-supply))
      (hashrate-amount (/ (* lp-amount current-hashrate-reserve) current-lp-supply))
    )
      (asserts! (>= user-balance lp-amount) err-insufficient-funds)
      (asserts! (>= stx-amount min-stx) err-slippage-too-high)
      (asserts! (>= hashrate-amount min-hashrate) err-slippage-too-high)

      ;; Burn LP tokens from user
      (try! (ft-burn? lp-token lp-amount tx-sender))

      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? stx-amount (as-contract tx-sender) tx-sender)))

      ;; Transfer hashrate tokens to user
      (try! (as-contract (ft-transfer? hashrate-token hashrate-amount (as-contract tx-sender) tx-sender)))

      ;; Update user LP balance
      (map-set user-lp-balances tx-sender (- user-balance lp-amount))

      ;; Update reserves
      (var-set stx-reserve (- current-stx-reserve stx-amount))
      (var-set hashrate-reserve (- current-hashrate-reserve hashrate-amount))
      (var-set total-lp-supply (- current-lp-supply lp-amount))

      (ok {stx: stx-amount, hashrate: hashrate-amount}))))

;; Swap STX for hashrate tokens
(define-public (swap-stx-for-hashrate (stx-in uint) (min-hashrate-out uint))
  (begin
    (asserts! (var-get pool-initialized) err-pool-not-initialized)
    (asserts! (> stx-in u0) err-zero-amount)

    (let (
      (current-stx-reserve (var-get stx-reserve))
      (current-hashrate-reserve (var-get hashrate-reserve))
      (stx-in-with-fee (- stx-in (/ (* stx-in fee-rate) fee-denominator)))
      (hashrate-out (/ (* stx-in-with-fee current-hashrate-reserve)
                      (+ current-stx-reserve stx-in-with-fee)))
    )
      (asserts! (>= hashrate-out min-hashrate-out) err-slippage-too-high)
      (asserts! (< hashrate-out current-hashrate-reserve) err-insufficient-liquidity)

      ;; Transfer STX from user
      (try! (stx-transfer? stx-in tx-sender (as-contract tx-sender)))

      ;; Transfer hashrate tokens to user
      (try! (as-contract (ft-transfer? hashrate-token hashrate-out (as-contract tx-sender) tx-sender)))

      ;; Update reserves
      (var-set stx-reserve (+ current-stx-reserve stx-in))
      (var-set hashrate-reserve (- current-hashrate-reserve hashrate-out))

      (ok hashrate-out))))

;; Swap hashrate tokens for STX
(define-public (swap-hashrate-for-stx (hashrate-in uint) (min-stx-out uint))
  (begin
    (asserts! (var-get pool-initialized) err-pool-not-initialized)
    (asserts! (> hashrate-in u0) err-zero-amount)

    (let (
      (current-stx-reserve (var-get stx-reserve))
      (current-hashrate-reserve (var-get hashrate-reserve))
      (user-hashrate-balance (ft-get-balance hashrate-token tx-sender))
      (hashrate-in-with-fee (- hashrate-in (/ (* hashrate-in fee-rate) fee-denominator)))
      (stx-out (/ (* hashrate-in-with-fee current-stx-reserve)
                (+ current-hashrate-reserve hashrate-in-with-fee)))
    )
      (asserts! (>= user-hashrate-balance hashrate-in) err-insufficient-funds)
      (asserts! (>= stx-out min-stx-out) err-slippage-too-high)
      (asserts! (< stx-out current-stx-reserve) err-insufficient-liquidity)

      ;; Transfer hashrate tokens from user
      (try! (ft-transfer? hashrate-token hashrate-in tx-sender (as-contract tx-sender)))

      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? stx-out (as-contract tx-sender) tx-sender)))

      ;; Update reserves
      (var-set stx-reserve (- current-stx-reserve stx-out))
      (var-set hashrate-reserve (+ current-hashrate-reserve hashrate-in))

      (ok stx-out))))

;; Mint hashrate tokens (admin function for cross-chain bridging)
(define-public (mint-hashrate-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-zero-amount)
    (ft-mint? hashrate-token amount recipient)))

;; Burn hashrate tokens (admin function for cross-chain bridging)
(define-public (burn-hashrate-tokens (amount uint))
  (begin
    (asserts! (> amount u0) err-zero-amount)
    (ft-burn? hashrate-token amount tx-sender)))

;; read only functions

;; Get current pool reserves
(define-read-only (get-reserves)
  {
    stx-reserve: (var-get stx-reserve),
    hashrate-reserve: (var-get hashrate-reserve),
    lp-supply: (var-get total-lp-supply)
  })

;; Get user LP token balance
(define-read-only (get-user-lp-balance (user principal))
  (default-to u0 (map-get? user-lp-balances user)))

;; Get user hashrate token balance
(define-read-only (get-user-hashrate-balance (user principal))
  (ft-get-balance hashrate-token user))

;; Calculate output amount for STX to hashrate swap
(define-read-only (get-stx-to-hashrate-price (stx-in uint))
  (let (
    (current-stx-reserve (var-get stx-reserve))
    (current-hashrate-reserve (var-get hashrate-reserve))
    (stx-in-with-fee (- stx-in (/ (* stx-in fee-rate) fee-denominator)))
  )
    (if (and (> stx-in u0) (var-get pool-initialized))
      (ok (/ (* stx-in-with-fee current-hashrate-reserve)
          (+ current-stx-reserve stx-in-with-fee)))
      err-invalid-amount)))

;; Calculate output amount for hashrate to STX swap
(define-read-only (get-hashrate-to-stx-price (hashrate-in uint))
  (let (
    (current-stx-reserve (var-get stx-reserve))
    (current-hashrate-reserve (var-get hashrate-reserve))
    (hashrate-in-with-fee (- hashrate-in (/ (* hashrate-in fee-rate) fee-denominator)))
  )
    (if (and (> hashrate-in u0) (var-get pool-initialized))
      (ok (/ (* hashrate-in-with-fee current-stx-reserve)
          (+ current-hashrate-reserve hashrate-in-with-fee)))
      err-invalid-amount)))

;; Check if pool is initialized
(define-read-only (is-pool-initialized)
  (var-get pool-initialized))

;; Get contract info
(define-read-only (get-contract-info)
  {
    owner: contract-owner,
    fee-rate: fee-rate,
    fee-denominator: fee-denominator,
    minimum-liquidity: minimum-liquidity
  })

;; private functions

;; Helper function to calculate minimum of two values
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Helper function to calculate maximum of two values
(define-private (max (a uint) (b uint))
  (if (> a b) a b))
