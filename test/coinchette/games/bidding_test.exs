defmodule Coinchette.Games.BiddingTest do
  use ExUnit.Case, async: true

  alias Coinchette.Games.Bidding
  alias Coinchette.Games.Card

  describe "new/2" do
    test "crée une nouvelle phase d'enchères avec carte retournée et position dealer" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)

      assert bidding.proposed_trump == :hearts
      # Joueur à droite du donneur
      assert bidding.current_bidder == 1
      assert bidding.round == 1
      assert bidding.taker == nil
      assert bidding.trump_suit == nil
      assert bidding.status == :in_progress
    end
  end

  describe "bid/2 - Premier tour" do
    setup do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)
      %{bidding: bidding}
    end

    test "joueur prend la couleur proposée", %{bidding: bidding} do
      {:ok, updated} = Bidding.bid(bidding, :take)

      assert updated.taker == 1
      assert updated.trump_suit == :hearts
      assert updated.status == :completed
    end

    test "joueur passe, passe au suivant", %{bidding: bidding} do
      {:ok, updated} = Bidding.bid(bidding, :pass)

      assert updated.current_bidder == 2
      assert updated.taker == nil
      assert updated.trump_suit == nil
      assert updated.status == :in_progress
    end

    test "tous passent au premier tour, passe au second tour", %{bidding: bidding} do
      # Joueur 1
      {:ok, b1} = Bidding.bid(bidding, :pass)
      # Joueur 2
      {:ok, b2} = Bidding.bid(b1, :pass)
      # Joueur 3
      {:ok, b3} = Bidding.bid(b2, :pass)
      # Joueur 4 (donneur)
      {:ok, b4} = Bidding.bid(b3, :pass)

      assert b4.round == 2
      # Recommence à droite du donneur
      assert b4.current_bidder == 1
      assert b4.status == :in_progress
    end

    test "erreur si on essaie de choisir une couleur au premier tour", %{bidding: bidding} do
      assert {:error, :must_take_or_pass_round_1} = Bidding.bid(bidding, {:choose, :spades})
    end
  end

  describe "bid/2 - Second tour" do
    setup do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)

      # Tous passent au premier tour
      {:ok, b1} = Bidding.bid(bidding, :pass)
      {:ok, b2} = Bidding.bid(b1, :pass)
      {:ok, b3} = Bidding.bid(b2, :pass)
      {:ok, b4} = Bidding.bid(b3, :pass)

      %{bidding: b4}
    end

    test "joueur choisit une autre couleur", %{bidding: bidding} do
      {:ok, updated} = Bidding.bid(bidding, {:choose, :spades})

      assert updated.taker == 1
      assert updated.trump_suit == :spades
      assert updated.status == :completed
    end

    test "erreur si on essaie de choisir la couleur proposée", %{bidding: bidding} do
      assert {:error, :cannot_choose_proposed_trump} = Bidding.bid(bidding, {:choose, :hearts})
    end

    test "erreur si couleur invalide", %{bidding: bidding} do
      assert {:error, :invalid_suit} = Bidding.bid(bidding, {:choose, :invalid})
    end

    test "joueur passe, passe au suivant", %{bidding: bidding} do
      {:ok, updated} = Bidding.bid(bidding, :pass)

      assert updated.current_bidder == 2
      assert updated.taker == nil
      assert updated.status == :in_progress
    end

    test "tous passent au second tour, enchères échouent", %{bidding: bidding} do
      # Joueur 1
      {:ok, b1} = Bidding.bid(bidding, :pass)
      # Joueur 2
      {:ok, b2} = Bidding.bid(b1, :pass)
      # Joueur 3
      {:ok, b3} = Bidding.bid(b2, :pass)
      # Joueur 4 (donneur)
      {:ok, b4} = Bidding.bid(b3, :pass)

      assert b4.status == :failed
      assert b4.taker == nil
      assert b4.trump_suit == nil
    end

    test "erreur si on essaie :take au second tour", %{bidding: bidding} do
      assert {:error, :cannot_take_round_2} = Bidding.bid(bidding, :take)
    end
  end

  describe "bid/2 - Erreurs" do
    test "erreur si enchères déjà terminées" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)
      {:ok, completed} = Bidding.bid(bidding, :take)

      assert {:error, :bidding_already_completed} = Bidding.bid(completed, :pass)
    end

    test "erreur si enchères ont échoué" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)

      # Tous passent au premier tour
      {:ok, b1} = Bidding.bid(bidding, :pass)
      {:ok, b2} = Bidding.bid(b1, :pass)
      {:ok, b3} = Bidding.bid(b2, :pass)
      {:ok, b4} = Bidding.bid(b3, :pass)

      # Tous passent au second tour
      {:ok, b5} = Bidding.bid(b4, :pass)
      {:ok, b6} = Bidding.bid(b5, :pass)
      {:ok, b7} = Bidding.bid(b6, :pass)
      {:ok, failed} = Bidding.bid(b7, :pass)

      assert {:error, :bidding_failed} = Bidding.bid(failed, :pass)
    end
  end

  describe "completed?/1" do
    test "retourne true si enchères terminées" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)
      {:ok, completed} = Bidding.bid(bidding, :take)

      assert Bidding.completed?(completed)
    end

    test "retourne false si enchères en cours" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)

      refute Bidding.completed?(bidding)
    end
  end

  describe "failed?/1" do
    test "retourne true si tous ont passé aux 2 tours" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)

      # Tous passent
      {:ok, b1} = Bidding.bid(bidding, :pass)
      {:ok, b2} = Bidding.bid(b1, :pass)
      {:ok, b3} = Bidding.bid(b2, :pass)
      {:ok, b4} = Bidding.bid(b3, :pass)
      {:ok, b5} = Bidding.bid(b4, :pass)
      {:ok, b6} = Bidding.bid(b5, :pass)
      {:ok, b7} = Bidding.bid(b6, :pass)
      {:ok, failed} = Bidding.bid(b7, :pass)

      assert Bidding.failed?(failed)
    end

    test "retourne false si enchères réussies" do
      proposed_card = %Card{suit: :hearts, rank: :seven}
      bidding = Bidding.new(proposed_card, dealer_position: 0)
      {:ok, completed} = Bidding.bid(bidding, :take)

      refute Bidding.failed?(completed)
    end
  end
end
