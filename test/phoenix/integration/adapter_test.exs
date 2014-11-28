Code.require_file "http_client.exs", __DIR__

defmodule Phoenix.Integration.AdapterTest do
  use ExUnit.Case
  use ConnHelper

  import ExUnit.CaptureIO

  Application.put_env(:phoenix, __MODULE__.ProdRouter, http: [port: "4807"])

  defmodule ProdRouter do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(conn, _) do
      send_resp conn, 200, "ok"
    end
  end

  Application.put_env(:phoenix, __MODULE__.DevRouter, http: [port: "4808"], debug_errors: true)

  defmodule DevRouter do
    use Phoenix.Router

    pipeline :before do
      plug :done
    end

    def done(_conn, _) do
      raise "oops"
    end
  end

  @prod 4807
  @dev  4808

  alias Phoenix.Integration.HTTPClient

  test "adapters starts on configured port and serves requests and stops for prod" do
    capture_io fn -> ProdRouter.start end

    {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
    assert resp.status == 200
    assert resp.body == "ok"

    ProdRouter.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@prod}", %{})
  end

  test "adapters starts on configured port and serves requests and stops for dev" do
    capture_io fn -> DevRouter.start end

    assert capture_log(fn ->
      {:ok, resp} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
      assert resp.status == 500
      assert resp.body =~ "RuntimeError at GET /"
    end) =~ "** (RuntimeError) oops"

    DevRouter.stop
    {:error, _reason} = HTTPClient.request(:get, "http://127.0.0.1:#{@dev}", %{})
  end
end
