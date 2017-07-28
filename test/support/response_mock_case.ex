defmodule Mailchimp.ResponseMockCase do
  @moduledoc """
  This module defines the test case to be used by
  response mock tests.
  """

  use ExUnit.CaseTemplate
  alias HTTPoison.Response

  using do
    quote do
      import Mock
      alias Mailchimp.HTTPClient

      defmacro with_response_mocks(mocks, do: test_block) do
        quote do
          Mock.with_mock Mailchimp.HTTPClient, [:passthrough], unquote(mocks), do: unquote(test_block)
        end
      end
    end
  end

  setup tags do
    responses = Map.get(tags, :response_mocks, [])
    |> Enum.map(fn {clause, {status_code, id}} ->
      {clause, %Response{status_code: status_code, body: Mailchimp.MockServer.get(id)}}
    end)
    |> Enum.reduce(%{}, fn {{method, url}, response}, acc ->
      url = clean_url(url)
      Map.update(acc, method, %{url => response}, fn method_responses ->
        Map.put(method_responses, url, response)
      end)
    end)

    response_mocks = [
      get: fn(url) ->
        url = clean_url(url)
        case responses[:get][url] do
          nil ->
            {:error, "Mock for GET #{url} not defined"}
          response ->
            {:ok, response}
        end
      end,
    ]
    {:ok, %{response_mocks: response_mocks}}
  end

  defp clean_url("/" <> url), do: URI.parse(url).path
  defp clean_url("http" <> url) do
    url = clean_url(URI.parse(url).path)
    [_version, url] = String.split(url, "/", parts: 2)
    url
  end
  defp clean_url(url), do: URI.parse(url).path
end
