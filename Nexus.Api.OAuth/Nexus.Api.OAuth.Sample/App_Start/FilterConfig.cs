using System.Web;
using System.Web.Mvc;

namespace Nexus.Api.OAuth.Sample
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            filters.Add(new HandleErrorAttribute());
        }
    }
}
