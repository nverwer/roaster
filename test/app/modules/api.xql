xquery version "3.1";

declare namespace api="http://e-editiones.org/roasted/test-api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace svg="http://www.w3.org/2000/svg";

import module namespace roaster="http://e-editiones.org/roaster";

import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors="http://e-editiones.org/roaster/errors";


(:~
 : list of definition files to use
 :)
declare variable $api:definitions := ("api.json");


(:~
 : You can add application specific route handlers here.
 : Having them in imported modules is preferred.
 :)

declare function api:date($request as map(*)) {
    $request?parameters?date instance of xs:date and
    $request?parameters?dateTime instance of xs:dateTime
};

(:~
 : An example how to throw a dynamic custom error (error:NOT_FOUND_404)
 : This error is handled in the router
 :)
declare function api:error-triggered($request as map(*)) {
    error($errors:NOT_FOUND, "document not found", "error details")
};

(:~
 : calling this function will throw dynamic XQuery error (err:XPST0003)
 :)
declare function api:error-dynamic($request as map(*)) {
    util:eval('1 + $undefined')
};

(:~
 : Handlers can also respond with an error directly 
 :)
declare function api:error-explicit($request as map(*)) {
    roaster:response(403, "application/xml", <forbidden/>)
};

(:~
 : This is used as an error-handler in the API definition 
 :)
declare function api:handle-error($error as map(*)) as element(html) {
    <html>
        <body>
            <h1>Error [{$error?code}]</h1>
            <p>{
                if (map:contains($error, "module"))
                then ``[An error occurred in `{$error?module}` at line `{$error?line}`, column `{$error?column}`]``
                else "An error occurred!"
            }</p>
            <h2>Description</h2>
            <p>{$error?description}</p>
        </body>
    </html>
};

declare function api:upload-data ($request as map(*)) {
    let $body :=
        if (
            $request?body instance of array(*) or
            $request?body instance of map(*)
        )
        then ($request?body => serialize(map { "method": "json" }))
        else ($request?body)

    let $stored := xmldb:store("/db/apps/roasted/uploads", $request?parameters?path, $body)
    return roaster:response(201, $stored)
};

declare function api:get-uploaded-data ($request as map(*)) {
    (: xml :)
    if (doc-available("/db/apps/roasted/uploads/" || $request?parameters?path))
    then (
        unparsed-text("/db/apps/roasted/uploads/" || $request?parameters?path)
        => util:base64-encode()
        => response:stream-binary("application/octet-stream", $request?parameters?path)
    )
    (: anything else :)
    else if (util:binary-doc-available("/db/apps/roasted/uploads/" || $request?parameters?path))
    then (
        util:binary-doc("/db/apps/roasted/uploads/" || $request?parameters?path)
        => response:stream-binary("application/octet-stream", $request?parameters?path)
    )
    else (
        error($errors:NOT_FOUND, "document " || $request?parameters?path || " not found", "error details")
    )
};

declare function api:avatar ($request as map(*)) {
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
        <g fill="darkgreen" stroke="lime" stroke-width=".25" transform="skewX(4) skewY(8) translate(0,.5)">{
            for $pos in 1 to 10
            let $zero-based := $pos - 1
            let $x := $zero-based mod 4 * 3 + 2
            let $y := $zero-based idiv 4 * 3 + 2
            return <rect x="{$x}" y="{$y}" width="2" height="2" rx=".5" ry=".5" />
        }</g>
    </svg>
};

(: end of route handlers :)

(:~
 : This function "knows" all modules and their functions
 : that are imported here 
 : You can leave it as it is, but it has to be here
 :)
declare function api:lookup ($name as xs:string) {
    function-lookup(xs:QName($name), 1)
};

(: util:declare-option("output:indent", "no"), :)
roaster:route($api:definitions, api:lookup#1)
