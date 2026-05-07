defmodule IcgtWeb.PageController do
  use IcgtWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
