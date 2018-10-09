defmodule Phauxth.AuthenticateToken do
  @moduledoc """
  Authenticates the user by verifying a Phauxth token.

  You need to define a `get_by(attrs)` function in the `session_module`
  module you are using - see the documentation for Phauxth.Config
  for more information about the `session_module`.

  ## Token authentication

  This module looks for a token in the request headers. It then uses
  Phauxth.Token to check that it is valid. If it is valid, user information
  is retrieved from the database.

  If you want to store the token in a cookie, see the documentation for
  Phauxth.Authenticate.Token, which has an example of how you can create
  a custom module to verify tokens stored in cookies.

  ## Options

  There are two options:

    * `:session_module` - the sessions module to be used
      * the default is Phauxth.Config.session_module()
    * `:log_meta` - additional custom metadata for Phauxth.Log
      * this should be a keyword list

  There are also options for signing / verifying the token.
  See the documentation for the Phauxth.Token module for details.

  ## Examples

  Add the following line to the pipeline you want to authenticate in
  the `web/router.ex` file:

      plug Phauxth.AuthenticateToken

  And if you are using a different sessions module:

      plug Phauxth.AuthenticateToken, session_module: MyApp.Sessions

  In the example above, you need to have the `get_by/1` function
  defined in MyApp.Sessions.
  """

  use Phauxth.Authenticate.Token
end
