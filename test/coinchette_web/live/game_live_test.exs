defmodule CoinchetteWeb.GameLiveTest do
  use CoinchetteWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "GameLive" do
    test "mounts and displays bidding interface", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/game")

      # Vérifie que la page charge
      assert html =~ "Coinchette"
      assert html =~ "enchères"  # Évite l'apostrophe échappée

      # Vérifie l'interface d'enchères
      assert html =~ "Carte retournée"
      assert html =~ "Couleur proposée"
      assert html =~ "Votre enchère"
    end

    test "displays bidding buttons in first round", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/game")

      # Premier tour - boutons Prendre et Passer
      assert html =~ "Je prends"
      assert html =~ "Je passe"
      assert html =~ "Premier tour"
    end

    test "shows proposed trump card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/game")

      # Vérifie qu'une carte est affichée (couleur proposée)
      assert html =~ "♠" or html =~ "♥" or html =~ "♦" or html =~ "♣"
      assert html =~ "Couleur proposée"
    end

    test "shows new game button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/game")

      # Vérifie que le bouton existe
      assert has_element?(view, "button", "Nouvelle Partie")
    end

    test "can start new game", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/game")

      # Clique sur nouvelle partie
      html = view |> element("button", "Nouvelle Partie") |> render_click()

      # Vérifie que la partie a redémarré
      assert html =~ "Nouvelle partie commencée"
      assert html =~ "enchères"  # Évite l'apostrophe échappée
    end

    test "can take trump in bidding", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/game")

      # Clique sur "Je prends"
      html = view |> element("button", "Je prends") |> render_click()

      # Après enchères, devrait afficher le plateau de jeu
      # (les bots jouent automatiquement, donc on devrait être en mode playing)
      assert html =~ "Votre tour de jouer" or html =~ "Le bot joue"
    end

    test "shows bidding round info", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/game")

      # Vérifie les infos des enchères
      assert html =~ "Tour :"
      assert html =~ "/ 2"
      assert html =~ "Enchérisseur actuel"
    end
  end
end
