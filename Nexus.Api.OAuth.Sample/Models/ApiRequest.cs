using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace App.Models
{
    public class ApiRequest
    {
        public string Action { get; set; }
        public string Uri { get; set; }
        public bool UseAuthentication { get; set; }

    }
}