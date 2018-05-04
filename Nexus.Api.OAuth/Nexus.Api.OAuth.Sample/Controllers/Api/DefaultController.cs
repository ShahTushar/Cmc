using System;
using System.Collections.Generic;
using System.Configuration;
using System.Net.Http;
using System.Web.Http;
using App.Models;
using IdentityModel.Client;

namespace Nexus.Api.OAuth.Sample.Controllers.Api
{
    /// <summary>
    /// Controller to demonstrate Application Identity with OAuth 2.0 Client Credentials
    /// </summary>
    public class DefaultController : ApiController
    {
        // POST: api/Default
        public ApiResponse Post(ApiRequest request)
        {
            ApiResponse result = CallSecureService(request);

            try
            {
                // Format data if successful result
                dynamic formattedOutput = Newtonsoft.Json.JsonConvert.DeserializeObject(result.Data);
                result.Data =
                    Newtonsoft.Json.JsonConvert.SerializeObject(formattedOutput, Newtonsoft.Json.Formatting.Indented);
            }
            catch
            {
                // do not modify result and return
            }
            return result;
        }

        /// <summary>
        /// Get token from Identity Server
        /// </summary>
        /// <returns></returns>
        private TokenResponse RequestToken()
        {
            string identityProviderTokenEndpointUri = ConfigurationManager.AppSettings["IdentityProviderTokenEndpointUri"];
            string clientName = ConfigurationManager.AppSettings["ClientName"];
            string clientSecret = ConfigurationManager.AppSettings["ClientSecret"];
            string clientScope = ConfigurationManager.AppSettings["ClientScope"];

            TokenClient client = new TokenClient(identityProviderTokenEndpointUri, clientName, clientSecret);
            TokenResponse requestTokenResult = client.RequestClientCredentialsAsync(clientScope).Result;
            return requestTokenResult;
        }

        /// <summary>
        /// Possible way of getting token for user
        /// </summary>
        /// <returns></returns>
        private TokenResponse RequestTokenForUser()
        {
            string identityProviderTokenEndpointUri = ConfigurationManager.AppSettings["IdentityProviderTokenEndpointUri"];
            string clientName = "privateWeb1";
            string clientSecret = ConfigurationManager.AppSettings["ClientSecret"];
            string clientScope = ConfigurationManager.AppSettings["ClientScope"];

            TokenClient client = new TokenClient(identityProviderTokenEndpointUri, clientName, clientSecret);
            TokenResponse requestTokenResult = client.RequestResourceOwnerPasswordAsync("administrator", "testing", clientScope)
                .Result;

            return requestTokenResult;
        }

        private ApiResponse CallSecureService(ApiRequest request)
        {
            string apiAddress = request.Uri;

            HttpClient client = new HttpClient
            {
                BaseAddress = new Uri(apiAddress)
            };

            TokenResponse token = RequestToken();

            if (token.AccessToken != null)
            {
                client.SetBearerToken(token.AccessToken);
            }

            HttpResponseMessage response = null;

            switch (request.Action.ToLower().Trim())
            {
                case "get":
                    response = client.GetAsync(apiAddress).Result;
                    break;
                case "post":
                    response = client.PostAsync(apiAddress,
                            new FormUrlEncodedContent(new List<KeyValuePair<string, string>>()))
                        .Result;
                    break;
            }

            ApiResponse model = new ApiResponse();

            if (response == null) return model;

            model.StatusCode = response.StatusCode.ToString();
            model.Data = response.Content.ReadAsStringAsync().Result;

            return model;
        }
    }
}
