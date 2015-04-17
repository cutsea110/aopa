module Data.Generic2 where

open import Sets
open import Data.Empty
open import Data.Unit using (⊤)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Data.Product using (Σ; ∃; _×_; _,_; proj₁; proj₂)
open import Function using (_∘_; id)
open import Level renaming (_⊔_ to _⊔ℓ_)

open import Relations
open import Relations.PowerTrans
open import AlgebraicReasoning.ExtensionalEquality 
            using (_≐_; ≐-refl; ≐-sym; ≐-trans; ≐-trans'; 
                   pre-∘-cong; post-∘-cong)
open import AlgebraicReasoning.Implications
open import AlgebraicReasoning.Sets
            using (⊆-begin_; _⊆⟨_⟩_; _⊆∎)

-- Polynomial bifunctors

data PolyF : Set where
  zer : PolyF 
  one  : PolyF
  arg₁ : PolyF
  arg₂ : PolyF
  _⊕_ : PolyF → PolyF → PolyF
  _⊗_ : PolyF → PolyF → PolyF

data Zero {i} : Set i where

data One {i} : Set i where
  tt : One

data Fst {i j} (A : Set i) : Set (i ⊔ℓ j) where
  fst : A → Fst {i} {j} A

data Snd {i j} (X : Set j) : Set (i ⊔ℓ j) where
  snd : X → Snd {i} {j} X

⟦_⟧ : PolyF → ∀{i j} → (A : Set i) (X : Set j) → Set (i ⊔ℓ j)
⟦ zer ⟧ A X = Zero
⟦ one ⟧ A X = One
⟦ arg₁ ⟧ {i} {j} A X = Fst {i} {j} A
⟦ arg₂ ⟧ {i} {j} A X = Snd {i} {j} X
⟦ l ⊕ r ⟧ A X = ⟦ l ⟧ A X ⊎ ⟦ r ⟧ A X
⟦ l ⊗ r ⟧ A X = ⟦ l ⟧ A X × ⟦ r ⟧ A X

data μ (F : PolyF) {i} (A : Set i) : Set i where
  In : ⟦ F ⟧ A (μ F A) → μ F A

bimap : (F : PolyF) → ∀ {i j k l} {A₁ : Set i} {A₂ : Set j} {B₁ : Set k} {B₂ : Set l}
        → (A₁ → A₂) → (B₁ → B₂) → ⟦ F ⟧ A₁ B₁ → ⟦ F ⟧ A₂ B₂
bimap zer f g ()
bimap one f g tt = tt
bimap arg₁ f g (fst a) = fst (f a)
bimap arg₂ f g (snd b) = snd (g b)
bimap (F₁ ⊕ F₂) f g (inj₁ x) = inj₁ (bimap F₁ f g x)
bimap (F₁ ⊕ F₂) f g (inj₂ y) = inj₂ (bimap F₂ f g y)
bimap (F₁ ⊗ F₂) f g (x , y) = bimap F₁ f g x , bimap F₂ f g y

bimap-comp : (F : PolyF) → ∀ {i j k l m n} {A₁ : Set i} {A₂ : Set j} {A₃ : Set k} {B₁ : Set l} {B₂ : Set m} {B₃ : Set n}
            → (f : A₂ → A₃) → (g : B₂ → B₃) → (h : A₁ → A₂) → (k : B₁ → B₂)
            → (∀ x → bimap F (f ∘ h) (g ∘ k) x ≡ bimap F f g (bimap F h k x))
bimap-comp zer f g h k ()
bimap-comp one f g h k tt = refl
bimap-comp arg₁ f g h k (fst x) = refl
bimap-comp arg₂ f g h k (snd y) = refl
bimap-comp (F₁ ⊕ F₂) f g h k (inj₁ x) = cong inj₁ (bimap-comp F₁ f g h k x)
bimap-comp (F₁ ⊕ F₂) f g h k (inj₂ y) = cong inj₂ (bimap-comp F₂ f g h k y)
bimap-comp (F₁ ⊗ F₂) f g h k (x , y)
  rewrite bimap-comp F₁ f g h k x | bimap-comp F₂ f g h k y = refl

-- functional fold 

mutual 
  fold : (F : PolyF) → ∀ {i j} {A : Set i} {B : Set j} 
       → (⟦ F ⟧ A B → B) → μ F A → B
  fold F f (In xs) = f (mapFold F F f xs)

  mapFold : (F G : PolyF) → ∀ {i j} {A : Set i} {B : Set j} 
          → (⟦ F ⟧ A B → B) → ⟦ G ⟧ A (μ F A) → ⟦ G ⟧ A B
  mapFold F zer f ()
  mapFold F one f tt = tt
  mapFold F arg₁ f (fst a) = fst a
  mapFold F arg₂ f (snd x) = snd (fold F f x)
  mapFold F (G₁ ⊕ G₂) f (inj₁ x) = inj₁ (mapFold F G₁ f x)
  mapFold F (G₁ ⊕ G₂) f (inj₂ y) = inj₂ (mapFold F G₂ f y)
  mapFold F (G₁ ⊗ G₂) f (x , y) = mapFold F G₁ f x , mapFold F G₂ f y

{-
  Universal property of fold:
    h ≐ fold F f  ≡  h ∘ In ≐ f ∘ bimap F id h
  We split it into two directions: fold-universal-⇐ and fold-universal-⇒.
-}

mutual

 fold-universal-⇐ : (F : PolyF) → ∀ {i j} {A : Set i} {B : Set j} 
                → (h : μ F A → B) → (f : ⟦ F ⟧ A B → B)
                → (h ∘ In ≐ f ∘ bimap F id h)
                → (h ≐ fold F f)
 fold-universal-⇐ F h f hom (In xs) 
   rewrite hom xs = cong f (mapFold-univ-⇐ F F h f hom xs)

 mapFold-univ-⇐ : (F G : PolyF) → ∀ {i j} {A : Set i} {B : Set j} 
               → (h : μ F A → B) → (f : ⟦ F ⟧ A B → B) 
               → (h ∘ In ≐ f ∘ bimap F id h)
               → bimap G id h ≐ mapFold F G f
 mapFold-univ-⇐ F zer h f hom ()
 mapFold-univ-⇐ F one h f hom tt = refl
 mapFold-univ-⇐ F arg₁ h f hom (fst a) = refl
 mapFold-univ-⇐ F arg₂ h f hom (snd xs) = cong snd (fold-universal-⇐ F h f hom xs)
 mapFold-univ-⇐ F (G₁ ⊕ G₂) h f hom (inj₁ x) = cong inj₁ (mapFold-univ-⇐ F G₁ h f hom x)
 mapFold-univ-⇐ F (G₁ ⊕ G₂) h f hom (inj₂ y) = cong inj₂ (mapFold-univ-⇐ F G₂ h f hom y)
 mapFold-univ-⇐ F (G₁ ⊗ G₂) h f hom (x , y) 
   rewrite mapFold-univ-⇐ F G₁ h f hom x | mapFold-univ-⇐ F G₂ h f hom y = refl

mutual
  fold-universal-⇒ : (F : PolyF) → ∀ {i j} {A : Set i} {B : Set j}
                    → (h : μ F A → B) → (f : ⟦ F ⟧ A B → B)
                    → (h ≐ fold F f)
                    → (h ∘ In ≐ f ∘ bimap F id h)
  fold-universal-⇒ F h f hom xs
    rewrite hom (In xs) = cong f (mapFold-univ-⇒ F F h f hom xs)

  mapFold-univ-⇒ : (F G : PolyF) → ∀ {i j} {A : Set i} {B : Set j}
                  → (h : μ F A → B) → (f : ⟦ F ⟧ A B → B)
                  → (h ≐ fold F f)
                  → mapFold F G f ≐ bimap G id h
  mapFold-univ-⇒ F zer h f hom ()
  mapFold-univ-⇒ F one h f hom tt = refl
  mapFold-univ-⇒ F arg₁ h f hom (fst x) = refl
  mapFold-univ-⇒ F arg₂ h f hom (snd y) = cong snd (sym (hom y))
  mapFold-univ-⇒ F (G₁ ⊕ G₂) h f hom (inj₁ x) = cong inj₁ (mapFold-univ-⇒ F G₁ h f hom x)
  mapFold-univ-⇒ F (G₁ ⊕ G₂) h f hom (inj₂ y) = cong inj₂ (mapFold-univ-⇒ F G₂ h f hom y)
  mapFold-univ-⇒ F (G₁ ⊗ G₂) h f hom (x , y)
    rewrite mapFold-univ-⇒ F G₁ h f hom x | mapFold-univ-⇒ F G₂ h f hom y = refl

fold-computation : (F : PolyF) → ∀ {i j} {A : Set i} {B : Set j} 
                 → (f : ⟦ F ⟧ A B → B)
                 → (fold F f ∘ In ≐ f ∘ bimap F id (fold F f))
fold-computation F f = fold-universal-⇒ F (fold F f) f ≐-refl

fold-fusion : (F : PolyF) → ∀ {i j} {A : Set i} {B C : Set j}
             → (h : B → C) → (f : ⟦ F ⟧ A B → B) → (g : ⟦ F ⟧ A C → C)
             → (h ∘ f ≐ g ∘ bimap F id h)
             → (h ∘ fold F f ≐ fold F g)
fold-fusion F h f g hom = 
   (⇐-begin 
      h ∘ fold F f ≐ fold F g
    ⇐⟨ fold-universal-⇐ F (h ∘ fold F f) g ⟩ 
      h ∘ fold F f ∘ In ≐ g ∘ bimap F id (h ∘ fold F f)
    ⇐⟨ ≐-trans (pre-∘-cong h (fold-computation F f)) ⟩ 
      h ∘ f ∘ bimap F id (fold F f) ≐ g ∘ bimap F id (h ∘ fold F f) 
    ⇐⟨ ≐-trans' (pre-∘-cong g (≐-sym (bimap-comp F id h id (fold F f)))) ⟩ 
      h ∘ f ∘ bimap F id (fold F f) ≐ g ∘ bimap F id h ∘ bimap F id (fold F f)
    ⇐⟨ post-∘-cong (bimap F id (fold F f)) ⟩ 
      h ∘ f ≐ g ∘ bimap F id h ⇐∎) hom

{-
  In the fold-fusion theorem proved above B and C must have the
  same level due to the restriction of AlgebraicReasoning.Implications.

  AlgebraicReasoning modules currently demands that all the 
  related components have the same type (or the same level, if they are Sets).

  If {A : Set i} {B : Set j} {C : Set k}, 
   h ∘ fold F f ≐ fold F g  :  Set (k ⊔ℓ i)  (and all the equations except the last one)
       since both sides have type μ F A → C, while
   h ∘ f ≐ g ∘ bimap F id h  :  Set (k ⊔ℓ (j ⊔ℓ i))
       since both side have type  ⟦ F ⟧ A B → C
  
  We temporarily sidestep the problem by letting {B C : Set j}.
-}

{- A direct, and more general proof. -}

fold-fusion' : (F : PolyF) → ∀ {i j k} {A : Set i} {B : Set j} {C : Set k}
             → (h : B → C) → (f : ⟦ F ⟧ A B → B) → (g : ⟦ F ⟧ A C → C)
             → (h ∘ f ≐ g ∘ bimap F id h)
             → (h ∘ fold F f ≐ fold F g)

fold-fusion' F h f g hom = fold-universal-⇐ F (h ∘ fold F f) g hom'
  where
    hom' : ∀ xs → h (fold F f (In xs)) ≡ g (bimap F id (h ∘ fold F f) xs)
    hom' xs rewrite fold-universal-⇒ F (fold F f) f (λ _ → refl) xs | 
                    bimap-comp F id h id (fold F f) xs = hom (bimap F id (fold F f) xs)

-- relational bimap

bimapR : (F : PolyF) → ∀ {i j k l} {A₁ : Set i} {A₂ : Set j} {B₁ : Set k} {B₂ : Set l}
        → (A₂ ← A₁ ⊣ zero) → (B₂ ← B₁ ⊣ zero) → (⟦ F ⟧ A₂ B₂ ← ⟦ F ⟧ A₁ B₁ ⊣ zero)
bimapR zer R S () _
bimapR one R S tt tt = ⊤  -- available only as Set.
bimapR arg₁ R S (fst a₁) (fst a₂) = R a₁ a₂
bimapR arg₂ R S (snd b₁) (snd b₂) = S b₁ b₂
bimapR (F₁ ⊕ F₂) R S (inj₁ x₁) (inj₁ x₂) = bimapR F₁ R S x₁ x₂
bimapR (F₁ ⊕ F₂) R S (inj₁ x₁) (inj₂ y₂) = ⊥
bimapR (F₁ ⊕ F₂) R S (inj₂ y₁) (inj₁ x₂) = ⊥
bimapR (F₁ ⊕ F₂) R S (inj₂ y₁) (inj₂ y₂) = bimapR F₂ R S y₁ y₂
bimapR (F₁ ⊗ F₂) R S (x₁ , y₁) (x₂ , y₂) = bimapR F₁ R S x₁ x₂ × bimapR F₂ R S y₁ y₂

bimapR-functor-⊑ : (F : PolyF) → ∀ {i j k l} {A₁ : Set i} {A₂ : Set} {A₃ : Set j} {B₁ : Set k} {B₂ : Set} {B₃ : Set l}
                   {R : A₃ ← A₂} {S : B₃ ← B₂} {T : A₂ ← A₁} {U : B₂ ← B₁}
                  → bimapR F R S ○ bimapR F T U ⊑ bimapR F (R ○ T) (S ○ U)
bimapR-functor-⊑ zer () _ _
bimapR-functor-⊑ one tt tt _ = Data.Unit.tt
bimapR-functor-⊑ arg₁ (fst z) (fst x) (fst y , yTx , zRy) = (y , yTx , zRy)
bimapR-functor-⊑ arg₂ (snd z) (snd x) (snd y , yUx , zSy) = (y , yUx , zSy)
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₁ z₁) (inj₁ x₁) (inj₁ y₁ , yTUx , zRSy) = bimapR-functor-⊑ F₁ z₁ x₁ (y₁ , yTUx , zRSy)
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₁ z₁) (inj₁ x₁) (inj₂ y₂ , () , ())
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₁ z₁) (inj₂ x₂) (inj₁ y₁ , () , zRSy)
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₁ z₁) (inj₂ x₂) (inj₂ y₂ , yTUx , ())
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₂ z₂) (inj₁ x₁) (inj₁ y₁ , yTUx , ())
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₂ z₂) (inj₁ x₁) (inj₂ y₂ , () , zRSy)
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₂ z₂) (inj₂ x₂) (inj₁ y₁ , () , ())
bimapR-functor-⊑ (F₁ ⊕ F₂) (inj₂ z₂) (inj₂ x₂) (inj₂ y₂ , yTUx , zRSy) = bimapR-functor-⊑ F₂ z₂ x₂ (y₂ , yTUx , zRSy)
bimapR-functor-⊑ (F₁ ⊗ F₂) (z₁ , z₂) (x₁ , x₂) ((y₁ , y₂) , yTUx , zRSy) =
   (bimapR-functor-⊑ F₁ z₁ x₁ (y₁ , (proj₁ yTUx) , (proj₁ zRSy)) , bimapR-functor-⊑ F₂ z₂ x₂ (y₂ , (proj₂ yTUx) , (proj₂ zRSy)))

bimapR-functor-⊒ : (F : PolyF) → ∀ {i j k l} {A₁ : Set i} {A₂ : Set} {A₃ : Set j} {B₁ : Set k} {B₂ : Set} {B₃ : Set l}
                   {R : A₃ ← A₂} {S : B₃ ← B₂} {T : A₂ ← A₁} {U : B₂ ← B₁}
                  → bimapR F R S ○ bimapR F T U ⊒ bimapR F (R ○ T) (S ○ U)
bimapR-functor-⊒ zer () _ _
bimapR-functor-⊒ one tt tt _ = (tt , Data.Unit.tt , Data.Unit.tt)
bimapR-functor-⊒ arg₁ (fst z) (fst x) (y , yTx , zRy) = (fst y , yTx , zRy)
bimapR-functor-⊒ arg₂ (snd z) (snd x) (y , yUx , zSy) = (snd y , yUx , zSy)
bimapR-functor-⊒ (F₁ ⊕ F₂) (inj₁ z₁) (inj₁ x₁) zRTSUx =
   let
     (y₁ , yRTx , zSUy) = bimapR-functor-⊒ F₁ z₁ x₁ zRTSUx
   in (inj₁ y₁ , yRTx , zSUy)
bimapR-functor-⊒ (F₁ ⊕ F₂) (inj₁ z₁) (inj₂ x₂) ()
bimapR-functor-⊒ (F₁ ⊕ F₂) (inj₂ z₂) (inj₁ x₁) ()
bimapR-functor-⊒ (F₁ ⊕ F₂) (inj₂ z₂) (inj₂ x₂) zRTSUx =
   let
     (y₂ , yRTx , zSUy) = bimapR-functor-⊒ F₂ z₂ x₂ zRTSUx
   in (inj₂ y₂ , yRTx , zSUy)
bimapR-functor-⊒ (F₁ ⊗ F₂) (z₁ , z₂) (x₁ , x₂) zRTSUx =
   let
     (y₁ , yRTx₁ , zSUy₁) = bimapR-functor-⊒ F₁ z₁ x₁ (proj₁ zRTSUx)
     (y₂ , yRTx₂ , zSUy₂) = bimapR-functor-⊒ F₂ z₂ x₂ (proj₂ zRTSUx)
   in ((y₁ , y₂) , (yRTx₁ , yRTx₂) , (zSUy₁ , zSUy₂))

bimapR-monotonic-⊑ : (F : PolyF) → ∀ {i j k l} {A : Set i} {B : Set j} {C : Set k} {D : Set l}
                     {R S : B ← A} {T U : D ← C}
                    → (R ⊑ S) → (T ⊑ U) → (bimapR F R T ⊑ bimapR F S U)
bimapR-monotonic-⊑ zer R⊑S T⊑U () _ _
bimapR-monotonic-⊑ one R⊑S T⊑U tt tt _ = Data.Unit.tt
bimapR-monotonic-⊑ arg₁ R⊑S T⊑U (fst b) (fst a) bRa = R⊑S b a bRa
bimapR-monotonic-⊑ arg₂ R⊑S T⊑U (snd d) (snd c) dTc = T⊑U d c dTc
bimapR-monotonic-⊑ (F₁ ⊕ F₂) R⊑S T⊑U (inj₁ y₁) (inj₁ x₁) yRTx = bimapR-monotonic-⊑ F₁ R⊑S T⊑U y₁ x₁ yRTx
bimapR-monotonic-⊑ (F₁ ⊕ F₂) R⊑S T⊑U (inj₁ y₁) (inj₂ x₂) ()
bimapR-monotonic-⊑ (F₁ ⊕ F₂) R⊑S T⊑U (inj₂ y₂) (inj₁ x₁) ()
bimapR-monotonic-⊑ (F₁ ⊕ F₂) R⊑S T⊑U (inj₂ y₂) (inj₂ x₂) yRTx = bimapR-monotonic-⊑ F₂ R⊑S T⊑U y₂ x₂ yRTx
bimapR-monotonic-⊑ (F₁ ⊗ F₂) R⊑S T⊑U (y₁ , y₂) (x₁ , x₂) yRTx =
   (bimapR-monotonic-⊑ F₁ R⊑S T⊑U y₁ x₁ (proj₁ yRTx) , bimapR-monotonic-⊑ F₂ R⊑S T⊑U y₂ x₂ (proj₂ yRTx))

bimapR-monotonic-⊒ : (F : PolyF) → ∀ {i j k l} {A : Set i} {B : Set j} {C : Set k} {D : Set l}
                     {R S : B ← A} {T U : D ← C}
                    → (R ⊒ S) → (T ⊒ U) → (bimapR F R T ⊒ bimapR F S U)
bimapR-monotonic-⊒ zer R⊒S T⊒U () _ _
bimapR-monotonic-⊒ one R⊒S T⊒U tt tt _ = Data.Unit.tt
bimapR-monotonic-⊒ arg₁ R⊒S T⊒U (fst b) (fst a) bRa = R⊒S b a bRa
bimapR-monotonic-⊒ arg₂ R⊒S T⊒U (snd d) (snd c) dTc = T⊒U d c dTc
bimapR-monotonic-⊒ (F₁ ⊕ F₂) R⊒S T⊒U (inj₁ y₁) (inj₁ x₁) yRTx = bimapR-monotonic-⊒ F₁ R⊒S T⊒U y₁ x₁ yRTx
bimapR-monotonic-⊒ (F₁ ⊕ F₂) R⊒S T⊒U (inj₁ y₁) (inj₂ x₂) ()
bimapR-monotonic-⊒ (F₁ ⊕ F₂) R⊒S T⊒U (inj₂ y₂) (inj₁ x₁) ()
bimapR-monotonic-⊒ (F₁ ⊕ F₂) R⊒S T⊒U (inj₂ y₂) (inj₂ x₂) yRTx = bimapR-monotonic-⊒ F₂ R⊒S T⊒U y₂ x₂ yRTx
bimapR-monotonic-⊒ (F₁ ⊗ F₂) R⊒S T⊒U (y₁ , y₂) (x₁ , x₂) yRTx =
   (bimapR-monotonic-⊒ F₁ R⊒S T⊒U y₁ x₁ (proj₁ yRTx) , bimapR-monotonic-⊒ F₂ R⊒S T⊒U y₂ x₂ (proj₂ yRTx))


mutual

{-
  foldR : (F : PolyF) → ∀ {i j k} {A : Set i} {B : Set j} 
                        → (B ← ⟦ F ⟧ A B ⊣ k) → (B ← μ F A)
  foldR F R b (In xs) = (R ○ bimapR F idR (foldR F R)) b xs -}

  foldR : (F : PolyF) → ∀ {A B : Set}
                        → (B ← ⟦ F ⟧ A B ⊣ zero) → (B ← μ F A)
  foldR F R y (In xs) = ∃ (λ ys → mapFoldR F F R ys xs × R y ys)
                        -- (R ○ mapFoldR F F R) y xs expanded

  mapFoldR : (F G : PolyF) → ∀ {A B : Set}
             → (B ← ⟦ F ⟧ A B) → (⟦ G ⟧ A B ← ⟦ G ⟧ A (μ F A) ⊣ zero)
  mapFoldR F zer R y ()
  mapFoldR F one R tt tt = ⊤  -- ⊤ : Set. Thus A has to be a Set.
  mapFoldR F arg₁ R (fst x₀) (fst x₁) = x₀ ≡ x₁
  mapFoldR F arg₂ R (snd x₀) (snd xs) = foldR F R x₀ xs -- foldR F R x₀ xs
  mapFoldR F (G₀ ⊕ G₁) R (inj₁ x₀) (inj₁ x₁) = mapFoldR F G₀ R x₀ x₁
  mapFoldR F (G₀ ⊕ G₁) R (inj₁ x₀) (inj₂ x₁) = ⊥
  mapFoldR F (G₀ ⊕ G₁) R (inj₂ x₀) (inj₁ x₁) = ⊥
  mapFoldR F (G₀ ⊕ G₁) R (inj₂ x₀) (inj₂ x₁) = mapFoldR F G₁ R x₀ x₁
  mapFoldR F (G₀ ⊗ G₁) R (x₀ , y₀) (x₁ , y₁) = mapFoldR F G₀ R x₀ x₁ × mapFoldR F G₁ R y₀ y₁
  

postulate
 eilenberg-wright : ∀ (F : PolyF) → {A B : Set} → (R : B ← ⟦ F ⟧ A B) 
                    → foldR F R ≑ ∈ ₁∘ fold F (Λ (R ○ bimapR F idR ∈))


mutual

  foldR-universal-⇐-⊑ : (F : PolyF) → {A B : Set}
                      → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                      → (S ○ fun In ⊑ R ○ bimapR F idR S)
                      → (S ⊑ foldR F R)
  foldR-universal-⇐-⊑ F S R hom b (In xs) bSInxs with 
    hom b xs (_ , refl , bSInxs)
  ... | (ys , ysbFxs , bRys) = ys , mapFoldR-univ-⇐-⊑ F F S R hom ys xs ysbFxs , bRys

  mapFoldR-univ-⇐-⊑ : (F G : PolyF) → {A B : Set}
                    → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                    → (S ○ fun In ⊑ R ○ bimapR F idR S)
                    → bimapR G idR S ⊑ mapFoldR F G R
  mapFoldR-univ-⇐-⊑ F zer S R hom () y bm
  mapFoldR-univ-⇐-⊑ F one S R hom tt tt bm = Data.Unit.tt
  mapFoldR-univ-⇐-⊑ F arg₁ S R hom (fst y) (fst .y) refl = refl
  mapFoldR-univ-⇐-⊑ F arg₂ S R hom (snd x) (snd y) bm = 
    foldR-universal-⇐-⊑ F S R hom x y bm
  mapFoldR-univ-⇐-⊑ F (G₀ ⊕ G₁) S R hom (inj₁ x₀) (inj₁ x₁) bm = 
    mapFoldR-univ-⇐-⊑ F G₀ S R hom x₀ x₁ bm
  mapFoldR-univ-⇐-⊑ F (G₀ ⊕ G₁) S R hom (inj₁ x) (inj₂ y) ()
  mapFoldR-univ-⇐-⊑ F (G₀ ⊕ G₁) S R hom (inj₂ y) (inj₁ x) ()
  mapFoldR-univ-⇐-⊑ F (G₀ ⊕ G₁) S R hom (inj₂ y₀) (inj₂ y₁) bm = 
    mapFoldR-univ-⇐-⊑ F G₁ S R hom y₀ y₁ bm
  mapFoldR-univ-⇐-⊑ F (G₀ ⊗ G₁) S R hom (x₀ , y₀) (x₁ , y₁) (bm₀ , bm₁) = 
    mapFoldR-univ-⇐-⊑ F G₀ S R hom x₀ x₁ bm₀ ,
    mapFoldR-univ-⇐-⊑ F G₁ S R hom y₀ y₁ bm₁

{-
mutual

  foldR-universal-⇒-⊑ : (F : PolyF) → {A B : Set}
                      → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                      → (S ⊑ foldR F R)
                      → (S ○ fun In ⊑ R ○ bimapR F idR S)
  foldR-universal-⇒-⊑ F S R S⊑fold b xs (._ , refl , bSInxs) with
    S⊑fold b (In xs) bSInxs
  ... | (ys , mF , bRys) = 
        ys , mapFoldR-univ-⇒-⊑ F F S R S⊑fold ys xs mF , bRys

  mapFoldR-univ-⇒-⊑ : (F G : PolyF) → {A B : Set}
                    → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                    → (S ⊑ foldR F R)
                    → mapFoldR F G R ⊑ bimapR G idR S
  mapFoldR-univ-⇒-⊑ F zer S R S⊑fold () xs x
  mapFoldR-univ-⇒-⊑ F one S R S⊑fold tt tt x = Data.Unit.tt
  mapFoldR-univ-⇒-⊑ F arg₁ S R S⊑fold (fst b) (fst ._) refl = refl
  mapFoldR-univ-⇒-⊑ F arg₂ S R S⊑fold (snd b) (snd (In xs)) mF = 
    {!foldR-universal-⇒-⊑ F S R S⊑fold b xs !}
  mapFoldR-univ-⇒-⊑ F (G ⊕ G₁) S R S⊑fold b xs x = {!!}
  mapFoldR-univ-⇒-⊑ F (G ⊗ G₁) S R S⊑fold b xs x = {!!}
-}

mutual

  foldR-universal-⇐-⊒ : (F : PolyF) → {A B : Set}
                      → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                      → (R ○ bimapR F idR S ⊑ S ○ fun In)
                      → (foldR F R ⊑ S)
  foldR-universal-⇐-⊒ F S R hom b (In xs) (ys , mF , bRys) with 
    hom b xs (ys , mapFoldR-univ-⇐-⊒ F F S R hom ys xs mF , bRys)
  ...  | (._ , refl , bSxs) = bSxs

  mapFoldR-univ-⇐-⊒ : (F G : PolyF) → {A B : Set}
                    → (S : B ← μ F A) → (R : B ← ⟦ F ⟧ A B)
                    → (R ○ bimapR F idR S ⊑ S ○ fun In)
                    → mapFoldR F G R ⊑ bimapR G idR S
  mapFoldR-univ-⇐-⊒ F zer S R hom () y bm
  mapFoldR-univ-⇐-⊒ F one S R hom tt tt bm = Data.Unit.tt
  mapFoldR-univ-⇐-⊒ F arg₁ S R hom (fst y) (fst .y) refl = refl
  mapFoldR-univ-⇐-⊒ F arg₂ S R hom (snd x) (snd y) bm = 
    foldR-universal-⇐-⊒ F S R hom x y bm
  mapFoldR-univ-⇐-⊒ F (G₀ ⊕ G₁) S R hom (inj₁ x₀) (inj₁ x₁) bm = 
    mapFoldR-univ-⇐-⊒ F G₀ S R hom x₀ x₁ bm
  mapFoldR-univ-⇐-⊒ F (G₀ ⊕ G₁) S R hom (inj₁ x) (inj₂ y) ()
  mapFoldR-univ-⇐-⊒ F (G₀ ⊕ G₁) S R hom (inj₂ y) (inj₁ x) ()
  mapFoldR-univ-⇐-⊒ F (G₀ ⊕ G₁) S R hom (inj₂ y₀) (inj₂ y₁) bm = 
    mapFoldR-univ-⇐-⊒ F G₁ S R hom y₀ y₁ bm
  mapFoldR-univ-⇐-⊒ F (G₀ ⊗ G₁) S R hom (x₀ , y₀) (x₁ , y₁) (bm₀ , bm₁) =
    mapFoldR-univ-⇐-⊒ F G₀ S R hom x₀ x₁ bm₀ ,
    mapFoldR-univ-⇐-⊒ F G₁ S R hom y₀ y₁ bm₁

foldR-computation-⊑ : (F : PolyF) → {A B : Set}
                     → (R : B ← ⟦ F ⟧ A B)
                     → (foldR F R ○ fun In ⊑ R ○ bimapR F idR (foldR F R))