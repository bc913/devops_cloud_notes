# Web Application with authentication & authorization using Azure AD B2C & App Service

This section describes the steps to create a consumer/client facing web application with backend(server as REST API) and frontend(client) code totally separated. The client application can access allowed resources through REST API exposed by the server side.

Authentication is also modeled using `Azure AD - B2C` resource. It lets the developer only concern about the business logic. Azure handles the authentication seemlessly smooth with very well integration.

Check out the sample repositories for [backend](https://github.com/bc913/azure_webapi) and [frontend](https://github.com/bc913/azure_mvcapp).

## 1. Create a subscription for the upcoming AAD-B2C tenant
- Create a subscription and resource group.
- In order to attach this subscription to a new AAD tenant, Microsoft.AzureActiveDirectory has to registered as resource provider for this subscription so
    1. Click to newly created subscription and make sure you navigated to the corresponding subscription detail page.
    2. Find and click `Resource Providers` under `Settings` section in the left pane.
    3. Type `Microsoft.AzureActiveDirectory` to the filter bar. Select the result and click `Register` on top.
    4. It might take few mins. Just refresh the page.

## 2. Create Azure AD B2C tenant
- Type `Azure Active Directory B2C` to the search bar and select the result under the `Marketplace` section.
- Click `Create a new Azure AD B2C Tenant`
- Fill the form with required information. Make sure you selected recently created subscription and resource group for this tenant.
- Click `Create` and wait for the result.
- After creation, click `Directories + subscriptions` icon in the top toolbar menu.

## 3. Transfer the subscription to AAD-B2C tenant
- Select the subscription from the portal's main page or `Subscriptions` menu item.
- Click `Overview` and then `Change Directory` shown on the top.
- Select the newly created tenant and wait for the result. It might take up to 10-15 mins to transfer it so wait.

## 4. Switch active directory to recently created AAD-B2C tenant
- Click `Directories + subscriptions` icon in the top toolbar menu.
- Make sure you have multiple directories listed. Click `Switch` for the AAD-B2C tenant(directory) to make it active.
- Azure Portal will reload the page for you and will mark the active directory as newly created AAD-B2C directory.
    - You can notice this change in the section located under the account email. (Left most section of the toolbar.)
    - You might lose your view settings at this point because those view settings belong to the prevoius directory so don't panic. It is normal.

## 5. Register and Expose the Web API for AAD-B2C tenant

### a. Register
- Select `Azure AD B2C` Azure service (Not the marketplace one).
- Select `App Registrations` and then `New Registration`.
- Provide a name (i.e. WebApi) and select `Accounts in any identity provider or organizational directory (for autenticating users with user flows).
    - This is selected because this app will be facing external clients with any form of identity (email/password or through external providers i.e. Google, Facebook, Apple)
- No `Redirect URI` is selected since this is an API. It is required for the client applications.
- Make sure `Grant admin consent to openid and offline_access permissions`.

### b. Expose
- Select the `Azure AD B2C` Azure service and then the `App Registrations` on the left pane.
- Click recently created application for the api.
- Select the `Expose an API` blade on the left.
    - Select Set next to the Application ID URI to generate a URI that is unique for this app.
    - For this sample, accept the proposed Application ID URI (https://{tenantName}.onmicrosoft.com/{clientId}) by selecting Save.

- All APIs have to publish at least one scope for the client's to obtain an access token successfully so this can be achieved by clicking `Add a scope`.
    - Enter the info for `Scope Name`.
    - Enter the infor for `Admin consent display name`.
    - Enter a description for it.
    - Make sure `State` is `Enabled`.
    - Click `Add Scope`.

## 6. Create & Configure Web API project
- The required information generated in `Azure Portal` has to be reflected within the web api project. It can be done through `dotnet cli` for a fresh project or by updating `appsettings.json` file in the existing project.

    - dotnet cli
    ```bash
    # Plain web api project
    dotnet new webapi -n MyWebApi
    # Web api project with auth settings tailored for AAD-B2C
    dotnet new webapi -n MyWebApi --auth IndividualB2C --aad-b2c-instance <azure_cloud_instance> --domain <Application_ID_generated_by_App_registration> --domain <AAD_B2C_tenant_name>
    ```

    - `appsettings.json` file in an existing web api project
    ```json
    "AzureAdB2C": {
        "Instance": "https://myaadb2ctenantname.b2clogin.com/",
        "ClientId": "<application_id_for_web_api_app",
        "Domain": "myaadb2ctenantname.onmicrosoft.com",
        "TenantId": "<azure_ad_b2c_tenant_id>",
        "SignUpSignInPolicyId": "B2C_1_susi"
    }
    ```
- How to collect the values:
    - **Instance (azure_cloud_instance)**: Azure public cloud instance identifier. It should be in the form of `https://<tenant_name>.b2clogin.com/`.
    - **ClientId**: This is the Application (Client) Id generated when the api is registered for the AAD-B2C tenant (Step 5.a). Click the corresponding app under `App Registration` to access the value.
    - **Domain(AAD_B2C_tenant_name)**: This is the fully qualified AAD-B2C domain name. It can be found by clicking the corresponding tenant under `Azure AD B2C` service.

- Add package reference to `Microsoft.Identity.Web` to your webapi project.
- Update the custom controller class
```csharp
// EventsController.cs

// add
using Microsoft.Identity.Web.Resource;

// Mark the controller with these two attributes
[Authorize]
[RequiredScope(scopeRequiredByApi)]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    // This is the scope name created at step 5.b
    internal const string scopeRequiredByApi = "access_as_user";
    /**/
}

```
- Startup.cs
```csharp
public void ConfigureServices(IServiceCollection services)
{
    services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddMicrosoftIdentityWebApi(options =>
    {
        Configuration.Bind("AzureAdB2C", options);

        options.TokenValidationParameters.NameClaimType = "name";
    },
    options => { Configuration.Bind("AzureAdB2C", options); });

    // Add other services
}

public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    // ...
    app.UseAuthentication(); //add this line
    app.UseAuthorization();
    /**/
}
```
## 7. Registration & permissions & secrets for the web client app
### Register
- Select `Azure AD B2C` Azure service (Not the marketplace one).
- Select `App Registrations` and then `New Registration`.
- Provide a name (i.e. WebApi) and select `Accounts in any identity provider or organizational directory (for autenticating users with user flows).
- Client apps usually require `Redirect URI` defined. It can be changed later.
    - Select `Web` as platform for MVC applications.
    - For development purposes, provide the one application url for the web client in your local machine, i.e. `https://localhost:5001/signin-oidc`.

### Permissions
- The client requires permission for access to an exposed scope.
- Select newly generated web client app from `App Registrations` page.
- Select `API Permissions` and then make sure that `My API` tab is selected.
- Select the app you registered for the web api and give the permission by checking the available scopes and then click `Add Permissions`.
- You're not done yet. As you might remember, this `access_as_user` scope requires admin consent so Make sure `Grant admin consent for <tenant_name>` is clicked.

### Secrets
The client app still requires a secret for authentication. 

> NOTE: Certificates can not be used to authenticate against Azure AD B2C so the only option is the `Client secret`.

- Go to `Azure AD B2C` Azure service in the portal and select `App Registrations`.
- Select the client app and click `Certificates and secrets`.
- Generate a secret by clicking `New Client Secret` with a meaningful description and expire date.
- Make sure you copy & save the generated `Value` somewhere else since it will be disappeared later.

## 8. Policies (user flows) for authentication
In order to embed Microsoft authentication architecture to your application requires the definition for policies. `User flows` under `Azure AD B2C` are used to configure/set up the most common auth scenerios. If one needs more advanced auth flows, check out `Identity Experience Framework` under under `Azure AD B2C`.

> NOTE: The default `User flow (policy)` is based on the custom email-password combo. It is marked as `Local account` under `Identity Providers`. If you need authentication through external providers, make sure you set them up through `Identity PRoviders`.

- Go to `User flows` under `Azure AD B2C` Azure service and click `New user flow`. 

### Sign up and sign in

#### Email authentication
1. **Name**: Provide a name as suffix to `B2C_1_`, i.e. `susi` so the full name is `B2C_1_susi`.
2. **Identity Providers**: Check `Email signup` under .
3. **Multifactor authentication**: Check `Email` for `Type of method` and keep `MFA Enforcement` as `Off` for the moment.
4. **Conditional Access**: ???
5. **User attributes and token claims**: Select the appropriate attributes and claims depending on your app needs.
    - User attributes are values collected on sign-up.
    - Return claims are values about the user returned to the application in the token.

### Profile editing
TODO

### Password reset
TODO

## 9. Create web client project
The following `dotnet cli` command will generate an mvc app with some settings configured and the required UI elements for the sign up/in/out logic.

```bash
dotnet new mvc -n MvcApp --auth IndividualB2C --aad-b2c-instance https://<tenant_name>.b2clogin.com/ --domain <tenant_name>.onmicrosoft.com --client-id <application_id_for_the_app> --tenant-id <tenant_id>
```

However, additional settings/configurations are still required.

### .csproj
These packages are included after generation of the project.
```xml
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="5.0.9" NoWarn="NU1605" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.OpenIdConnect" Version="5.0.9" NoWarn="NU1605" />
<PackageReference Include="Microsoft.Identity.Web" Version="1.1.0" />
<PackageReference Include="Microsoft.Identity.Web.UI" Version="1.1.0" />
```

`Microsoft.Identity.Web.UI` is crucial piece to get the auth related information during runtime.

### appsettings.json
```json
"AzureAdB2C": {
    "Instance": "https://<tenant_name>.b2clogin.com/",
    "ClientId": "<application_id_for_client_app>",
    "Domain": "<tenant_name>.onmicrosoft.com",
    "TenantId": "<azure_ad_b2c_tenant_id>",
    "ClientSecret": "<client_secret_value_generated_at_step_7>",
    "SignedOutCallbackPath": "/signout/B2C_1_susi",
    "SignUpSignInPolicyId": "B2C_1_susi",
    "CallbackPath": "/signin-oidc"
  },
  "WebApi": {
    "Scope": "https://<tenant_name>.onmicrosoft.com/<web_api_app_client_id>/<exposed_scope_name>",
    "BaseAddress": "https://localhost:44332"
  },
```

### Startup.cs
```csharp
public void ConfigureServices(IServiceCollection services)
{
    IdentityModelEventSource.ShowPII = true;
    //ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;


    // services.AddDistributedMemoryCache();

    services.Configure<CookiePolicyOptions>(options =>
    {
        // This lambda determines whether user consent for non-essential cookies is needed for a given request.
        options.CheckConsentNeeded = context => true;
        options.MinimumSameSitePolicy = SameSiteMode.Unspecified;
        // Handling SameSite cookie according to https://docs.microsoft.com/en-us/aspnet/core/security/samesite?view=aspnetcore-3.1
        options.HandleSameSiteCookieCompatibility();
    });

    services.AddMicrosoftIdentityWebAppAuthentication(Configuration, Constants.AzureAdB2C)
            .EnableTokenAcquisitionToCallDownstreamApi(new string[] { Configuration["WebApi:Scope"] })
            .AddInMemoryTokenCaches();

    // Add API
    services.AddUserService(Configuration);

    services.AddControllersWithViews().AddMicrosoftIdentityUI();
    // services.AddControllersWithViews(options =>
    // {
    //     var policy = new AuthorizationPolicyBuilder()
    //         .RequireAuthenticatedUser()
    //         .Build();
    //     options.Filters.Add(new AuthorizeFilter(policy));
    // });
    services.AddRazorPages();
    services.AddOptions();
    services.Configure<OpenIdConnectOptions>(Configuration.GetSection("AzureAdB2C"));
}

public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    /*
    *
    *
    */

    app.UseCookiePolicy(); //make sure this is added
    app.UseRouting();

    app.UseAuthentication(); // make sure this is added.
    app.UseAuthorization();
}
```

### UI Code


## 10. Create App Service resources for Web Api and Client App
Generate `App Service` using `Web App` for both Web api and the client app. I have preferred to locate them under different resource groups but other approaches might be possible as well. Check [App Service](AppService.md) notes for details.

## References
- [Azure Active Directory - B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/)
- [web app that calls a web API by using Azure AD B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/configure-authentication-sample-web-app-with-api?tabs=visual-studio)
- [Learning path](https://github.com/Azure-Samples/active-directory-aspnetcore-webapp-openidconnect-v2)
- [Secure a .NET Core API using Bearer Authentication](https://dotnetplaybook.com/secure-a-net-core-api-using-bearer-authentication/)
- [Azure AD B2C: Call an ASP.NET Web API from an ASP.NET Web App](https://github.com/Azure-Samples/active-directory-b2c-dotnet-webapp-and-webapi)
- [Microsoft Docs - Code Configuration](https://docs.microsoft.com/en-us/azure/active-directory/develop/scenario-web-app-sign-user-app-configuration?tabs=aspnetcore#configuration-files)

### Videos
- [Working with Azure AD B2C in ASP.NET](https://www.youtube.com/watch?v=oG9GcYIuYQM)
- [Create Secure Blazor WebAssembly & ASP.NET Core API Project with Azure Active Directory B2C](https://www.youtube.com/watch?v=S5PRH_N7pag)
- [How to use Azure AD B2C to Authenticate Users in an ASP.NET Core Web App](https://www.youtube.com/watch?v=lqfsKtoLHMQ)

### App service
- [Tutorial: Authenticate and authorize users end-to-end in Azure App Service](https://docs.microsoft.com/en-us/azure/app-service/tutorial-auth-aad?pivots=platform-linux)

### Troubleshooting
- [reply url mismatch](https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/error-code-aadsts50011-reply-url-mismatch)
