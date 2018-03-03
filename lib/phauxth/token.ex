defmodule Phauxth.Token do
  @moduledoc """
  Create api tokens.

  The data stored in the token is signed to prevent tampering
  but not encrypted. This means it is safe to store identification
  information (such as user IDs), but it should not be used to store
  confidential information (such as credit card numbers).

  ## Arguments to sign/3 and verify/3

  The first argument to both `sign/3` and `verify/3` is the `key_source`,
  from which the function can extract the secret key base. This can be one of:

    * the module name of a Phoenix endpoint
    * a `Plug.Conn` struct
    * a `Phoenix.Socket` struct
    * a string, representing the secret key base itself
      * this string should be at least 20 randomly generated characters long

  The second argument to sign/3 is the data to be signed, which can be
  an integer or string identifying the user, or a map with the user
  parameters.

  The second argument to verify/3 is the token to be verified.

  The third argument to sign/3, or verify/3, is the `opts`, the `max_age`
  and key generator options.

  The `max_age` option is used when signing the token, and it is the number
  of seconds which the token is valid for. The default value is 14400 (4 hours).

  The key generator has three options:

    * `:key_iterations` - the number of iterations the key derivation function uses
      * the default is 1000
    * `:key_length` - the length of the key, in bytes
      * the default is 32
    * `:key_digest` - the hash algorithm that is used
      * the default is :sha256
    * `:token_salt` - the salt to be used when generating the secret key
      * the default is the value set in the config

  Note that the same key generator options should be used for signing
  and verifying tokens.
  """

  @type key_source :: module | Plug.Conn.t() | String.t()
  @type token_data :: map | String.t() | integer
  @type result :: {:ok, token_data} | {:error, String.t()}

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  alias Phauxth.Config

  @doc """
  Sign the token.

  See the module documentation for more information.
  """
  @spec sign(key_source, token_data, keyword) :: String.t()
  def sign(key_source, data, opts \\ []) do
    age = opts[:max_age] || 14400
    %{"data" => data, "exp" => System.system_time(:second) + age}
    |> Jason.encode!()
    |> MessageVerifier.sign(gen_secret(key_source, opts))
  end

  @doc """
  Verify the token.

  See the module documentation for more information.
  """
  @spec verify(key_source, String.t(), keyword) :: result
  def verify(key_source, token, opts \\ [])

  def verify(key_source, token, opts) when is_binary(token) do
    MessageVerifier.verify(token, gen_secret(key_source, opts))
    |> get_token_data
    |> handle_verify()
  end

  def verify(_, _, _), do: {:error, "invalid token"}

  defp gen_secret(key_source, opts) do
    get_key_base(key_source) |> validate_secret |> run_kdf(opts)
  end

  defp get_key_base(%Plug.Conn{secret_key_base: key}), do: key
  defp get_key_base(%{endpoint: endpoint}), do: get_endpoint_key_base(endpoint)

  defp get_key_base(endpoint) when is_atom(endpoint) do
    get_endpoint_key_base(endpoint)
  end

  defp get_key_base(key) when is_binary(key), do: key

  defp get_endpoint_key_base(endpoint) do
    endpoint.config(:secret_key_base) ||
      raise """
      no :secret_key_base configuration found in #{inspect(endpoint)}.
      """
  end

  defp run_kdf(secret_key_base, opts) do
    token_salt = Keyword.get(opts, :token_salt, Config.token_salt())

    key_opts = [
      iterations: opts[:key_iterations] || 1000,
      length: validate_len(opts[:key_length]),
      digest: validate_digest(opts[:key_digest]),
      cache: Plug.Keys
    ]

    KeyGenerator.generate(secret_key_base, token_salt, key_opts)
  end

  defp get_token_data({:ok, message}), do: Jason.decode(message)
  defp get_token_data(:error), do: {:error, "invalid token"}

  defp handle_verify({:ok, %{"data" => data, "exp" => exp}}) do
    if exp < now(), do: {:error, "expired token"}, else: {:ok, data}
  end

  defp handle_verify(_), do: {:error, "invalid token"}

  defp now, do: System.system_time(:second)

  defp validate_secret(nil) do
    raise ArgumentError, "The secret_key_base has not been set"
  end

  defp validate_secret(key) when byte_size(key) < 20 do
    raise ArgumentError, "The secret_key_base is too short. It should be at least 20 bytes long."
  end

  defp validate_secret(key), do: key

  defp validate_len(nil), do: 32

  defp validate_len(len) when len < 20 do
    raise ArgumentError, "The key_length is too short. It should be at least 20 bytes long."
  end

  defp validate_len(len), do: len

  defp validate_digest(nil), do: :sha256
  defp validate_digest(digest) when digest in [:sha256, :sha512], do: digest

  defp validate_digest(digest) do
    raise ArgumentError, "Phauxth.Token does not support #{digest}"
  end
end
