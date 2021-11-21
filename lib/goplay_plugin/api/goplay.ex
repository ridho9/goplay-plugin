defmodule GoplayPlugin.API.Goplay do
  def event_details(host, slug) do
    url = "https://#{host}/api/v1/live/event/#{slug}"

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(url, [{"Cookie", "gp_fgp"}]),
         {:ok, %{"error" => nil, "data" => body}} <- Jason.decode(body) do
      {:ok, body}
    else
      _ -> {:error, "invalid event"}
    end
  end
end
