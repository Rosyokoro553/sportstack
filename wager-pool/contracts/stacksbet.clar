;; BetSport: Decentralized Wagering System for Sporting Events
;; A comprehensive smart contract that enables the creation and management 
;; of betting pools for sporting events with multiple reward systems
;; (equal distribution, stake-based, and fixed-rate), transparent wagering,
;; and automated reward distribution.

;; Error Constants
(define-constant admin-principal tx-sender)
(define-constant ERR-ACCESS-DENIED (err u100))
(define-constant ERR-DUPLICATE-MATCH (err u101))
(define-constant ERR-MATCH-DOES-NOT-EXIST (err u102))
(define-constant ERR-WAGERING-DISABLED (err u103))
(define-constant ERR-FUNDS-TOO-LOW (err u104))
(define-constant ERR-OUTCOME-ALREADY-DETERMINED (err u105))
(define-constant ERR-EARLY-MATCH-CLOSURE (err u106))
(define-constant ERR-EARLY-MATCH-CANCELLATION (err u107))
(define-constant ERR-TOO-FEW-OPTIONS (err u108))
(define-constant ERR-INVALID-CLOSING-HEIGHT (err u109))
(define-constant ERR-UNKNOWN-REWARD-MODEL (err u110))
(define-constant ERR-PAYOUT-RATES-NEEDED (err u111))
(define-constant ERR-OUTCOME-CHOICE-INVALID (err u112))
(define-constant ERR-MATCH-CONCLUDED (err u113))
(define-constant ERR-WINNING-OPTIONS-REQUIRED (err u114))
(define-constant ERR-MAX-WINNERS-EXCEEDED (err u115))
(define-constant ERR-INVALID-WINNER-IDS (err u116))
(define-constant ERR-BET-NOT-WINNING (err u117))
(define-constant ERR-REFUND-FAILED (err u118))
(define-constant ERR-REFUND-EXCEPTION (err u119))
(define-constant ERR-EMPTY-MATCH-DESCRIPTION (err u120))
(define-constant ERR-WAGER-AMOUNT-INVALID (err u121))

;; Data variables
(define-data-var match-counter uint u0)

;; Available reward distribution methods
(define-data-var reward-distribution-models (list 10 (string-ascii 20)) 
  (list "equal-distribution" "stake-proportional" "fixed-rate"))

;; Sports match data structure
(define-map sporting-matches
  { match-id: uint }
  {
    host-address: principal,
    match-summary: (string-ascii 256),
    outcome-choices: (list 10 (string-ascii 64)),
    total-wagered-amount: uint,
    accepting-wagers: bool,
    correct-outcomes: (list 5 uint),
    wager-deadline-block: uint,
    reward-model: (string-ascii 20),
    outcome-payouts: (optional (list 10 uint))
  }
)

;; Wager tracking structure
(define-map player-wagers
  { match-id: uint, player-address: principal }
  { chosen-outcome: uint, wagered-amount: uint }
)

;; Read-only functions

(define-read-only (get-match-details (match-id uint))
  (map-get? sporting-matches { match-id: match-id })
)

(define-read-only (get-player-wager (match-id uint) (player-address principal))
  (map-get? player-wagers { match-id: match-id, player-address: player-address })
)

(define-read-only (get-current-height)
  block-height
)

;; Private utility functions

(define-private (compute-reward-amount 
  (match-data { 
    host-address: principal, 
    match-summary: (string-ascii 256), 
    outcome-choices: (list 10 (string-ascii 64)), 
    total-wagered-amount: uint, 
    accepting-wagers: bool, 
    correct-outcomes: (list 5 uint), 
    wager-deadline-block: uint, 
    reward-model: (string-ascii 20), 
    outcome-payouts: (optional (list 10 uint)) 
  }) 
  (wager-data { chosen-outcome: uint, wagered-amount: uint }) 
  (winning-outcomes (list 5 uint)))
  
  (let
    (
      (distribution-type (get reward-model match-data))
      (wager-pool (get total-wagered-amount match-data))
      (player-stake (get wagered-amount wager-data))
    )
    (if (is-eq distribution-type "equal-distribution")
      ;; For equal distribution, divide total pot by number of winning outcomes
      (/ wager-pool (len winning-outcomes))
      
      (if (is-eq distribution-type "stake-proportional")
        ;; For stake-proportional, payout based on relative stake size
        (/ (* player-stake wager-pool) wager-pool)
        
        ;; Fixed-rate payout calculation
        (let
          (
            (payout-rates (unwrap! (get outcome-payouts match-data) u0))
            (chosen-rate (unwrap! (element-at payout-rates (- (get chosen-outcome wager-data) u1)) u0))
          )
          (+ player-stake (* player-stake (/ chosen-rate u100)))
        )
      )
    )
  )
)

(define-private (get-outcome-wager-amount (outcome-id uint) (match-id uint))
  (let
    (
      (player-wager (get-player-wager match-id tx-sender))
    )
    (if (is-some player-wager)
      (let
        ((wager-details (unwrap! player-wager u0)))
        (if (is-eq (get chosen-outcome wager-details) outcome-id)
          (get wagered-amount wager-details)
          u0
        )
      )
      u0
    )
  )
)

(define-private (get-outcome-total-wagers (outcome-id uint))
  (get-outcome-wager-amount outcome-id (var-get match-counter))
)

(define-private (process-match-refunds (match-id uint))
  (let
    ((player-wager (get-player-wager match-id tx-sender)))
    (match player-wager
      wager-details (match (as-contract (stx-transfer? (get wagered-amount wager-details) tx-sender tx-sender))
        success (begin
          (map-delete player-wagers { match-id: match-id, player-address: tx-sender })
          (ok true)
        )
        error ERR-REFUND-FAILED
      )
      ERR-REFUND-EXCEPTION
    )
  )
)

(define-private (verify-outcome-selections (outcomes (list 5 uint)) (max-valid-outcome uint))
  (let
    (
      (first-outcome (element-at outcomes u0))
      (second-outcome (element-at outcomes u1))
      (third-outcome (element-at outcomes u2))
      (fourth-outcome (element-at outcomes u3))
      (fifth-outcome (element-at outcomes u4))
    )
    (and
      ;; Check if first outcome exists and is valid
      (match first-outcome
        value (and (> value u0) (<= value max-valid-outcome))
        true)
      ;; For remaining outcomes, they're either valid or none
      (match second-outcome
        value (and (> value u0) (<= value max-valid-outcome))
        true)
      (match third-outcome
        value (and (> value u0) (<= value max-valid-outcome))
        true)
      (match fourth-outcome
        value (and (> value u0) (<= value max-valid-outcome))
        true)
      (match fifth-outcome
        value (and (> value u0) (<= value max-valid-outcome))
        true)
    )
  )
)

;; Public functions

(define-public (create-new-match 
  (match-description (string-ascii 256)) 
  (possible-outcomes (list 10 (string-ascii 64))) 
  (close-height uint) 
  (reward-distribution (string-ascii 20)) 
  (payout-rates (optional (list 10 uint))))
  
  (let
    (
      (new-match-id (var-get match-counter))
    )
    ;; Validate match creation parameters
    (asserts! (> (len match-description) u0) ERR-EMPTY-MATCH-DESCRIPTION)
    (asserts! (> (len possible-outcomes) u1) ERR-TOO-FEW-OPTIONS)
    (asserts! (> close-height block-height) ERR-INVALID-CLOSING-HEIGHT)
    (asserts! (is-some (index-of (var-get reward-distribution-models) reward-distribution)) 
              ERR-UNKNOWN-REWARD-MODEL)
    (asserts! (or (is-eq reward-distribution "equal-distribution") 
                 (is-eq reward-distribution "stake-proportional") 
                 (is-some payout-rates)) ERR-PAYOUT-RATES-NEEDED)
    
    ;; Create the new sporting match
    (map-set sporting-matches
      { match-id: new-match-id }
      {
        host-address: tx-sender,
        match-summary: match-description,
        outcome-choices: possible-outcomes,
        total-wagered-amount: u0,
        accepting-wagers: true,
        correct-outcomes: (list),
        wager-deadline-block: close-height,
        reward-model: reward-distribution,
        outcome-payouts: payout-rates
      }
    )
    
    ;; Increment the match counter
    (var-set match-counter (+ new-match-id u1))
    (ok new-match-id)
  )
)

(define-public (place-wager (match-id uint) (outcome-choice uint) (wager-amount uint))
  (let
    (
      (match-data (unwrap! (get-match-details match-id) ERR-MATCH-DOES-NOT-EXIST))
      (existing-wager (default-to { chosen-outcome: u0, wagered-amount: u0 } 
                       (get-player-wager match-id tx-sender)))
    )
    ;; Validate wager placement conditions
    (asserts! (> wager-amount u0) ERR-WAGER-AMOUNT-INVALID)
    (asserts! (get accepting-wagers match-data) ERR-WAGERING-DISABLED)
    (asserts! (>= (len (get outcome-choices match-data)) outcome-choice) ERR-OUTCOME-CHOICE-INVALID)
    (asserts! (< block-height (get wager-deadline-block match-data)) ERR-MATCH-CONCLUDED)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? wager-amount tx-sender (as-contract tx-sender)))
    
    ;; Record the player's wager
    (map-set player-wagers
      { match-id: match-id, player-address: tx-sender }
      {
        chosen-outcome: outcome-choice,
        wagered-amount: (+ wager-amount (get wagered-amount existing-wager))
      }
    )
    
    ;; Update total wagered amount
    (map-set sporting-matches
      { match-id: match-id }
      (merge match-data { total-wagered-amount: (+ (get total-wagered-amount match-data) wager-amount) })
    )
    (ok true)
  )
)

(define-public (close-match-wagering (match-id uint))
  (let
    (
      (match-data (unwrap! (get-match-details match-id) ERR-MATCH-DOES-NOT-EXIST))
    )
    ;; Check authorization and conditions
    (asserts! (or (is-eq (get host-address match-data) tx-sender) 
                 (is-eq admin-principal tx-sender)) ERR-ACCESS-DENIED)
    (asserts! (get accepting-wagers match-data) ERR-WAGERING-DISABLED)
    (asserts! (>= block-height (get wager-deadline-block match-data)) ERR-EARLY-MATCH-CLOSURE)
    
    ;; Close wagering for this match
    (map-set sporting-matches
      { match-id: match-id }
      (merge match-data { accepting-wagers: false })
    )
    (ok true)
  )
)

(define-public (cancel-match (match-id uint))
  (let
    (
      (match-data (unwrap! (get-match-details match-id) ERR-MATCH-DOES-NOT-EXIST))
    )
    ;; Check authorization and conditions
    (asserts! (is-eq (get host-address match-data) tx-sender) ERR-ACCESS-DENIED)
    (asserts! (get accepting-wagers match-data) ERR-WAGERING-DISABLED)
    (asserts! (< block-height (get wager-deadline-block match-data)) ERR-EARLY-MATCH-CANCELLATION)
    
    ;; Close wagering and initiate refunds
    (map-set sporting-matches
      { match-id: match-id }
      (merge match-data { accepting-wagers: false })
    )
    
    ;; Process refunds for the caller
    (process-match-refunds match-id)
  )
)

(define-public (collect-winnings (match-id uint))
  (let
    (
      (match-data (unwrap! (get-match-details match-id) ERR-MATCH-DOES-NOT-EXIST))
      (player-wager (unwrap! (get-player-wager match-id tx-sender) ERR-MATCH-DOES-NOT-EXIST))
      (winning-outcomes (get correct-outcomes match-data))
    )
    ;; Verify this is a winning wager
    (asserts! (is-some (index-of winning-outcomes (get chosen-outcome player-wager))) ERR-BET-NOT-WINNING)
    
    ;; Calculate and transfer winnings
    (let
      (
        (reward-amount (compute-reward-amount match-data player-wager winning-outcomes))
      )
      (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
      (map-delete player-wagers { match-id: match-id, player-address: tx-sender })
      (ok reward-amount)
    )
  )
)

(define-public (set-match-outcome (match-id uint) (outcome-ids (list 5 uint)))
  (let
    (
      (match-data (unwrap! (get-match-details match-id) ERR-MATCH-DOES-NOT-EXIST))
    )
    ;; Verify authorization and conditions
    (asserts! (is-eq admin-principal tx-sender) ERR-ACCESS-DENIED)
    (asserts! (not (get accepting-wagers match-data)) ERR-WAGERING-DISABLED)
    (asserts! (is-eq (len (get correct-outcomes match-data)) u0) ERR-OUTCOME-ALREADY-DETERMINED)
    (asserts! (> (len outcome-ids) u0) ERR-WINNING-OPTIONS-REQUIRED)
    (asserts! (<= (len outcome-ids) u5) ERR-MAX-WINNERS-EXCEEDED)
    
    ;; Validate outcome selections
    (asserts! (verify-outcome-selections outcome-ids (len (get outcome-choices match-data))) 
              ERR-INVALID-WINNER-IDS)
    
    ;; Record winning outcomes
    (map-set sporting-matches
      { match-id: match-id }
      (merge match-data { correct-outcomes: outcome-ids })
    )
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set match-counter u0)
)

;; Component contract export
(define-public (BetSportComponent)
  (ok true))