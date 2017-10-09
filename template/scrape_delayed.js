var url ='https://my.clemson.edu/#/directory/search/Daqaq';
var outFile ='data/clemson/Daqaq.html';
var page = new WebPage()
var fs = require('fs');


page.open(url, function (status) {
    just_wait();
});

function just_wait() {
    setTimeout(function () {
        fs.write(outFile, page.content, 'w');
        phantom.exit();
    }, 2000);
}
