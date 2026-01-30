defmodule CoinchetteWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use CoinchetteWeb, :html

  embed_templates "page_html/*"
end
