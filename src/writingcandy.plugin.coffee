# Export Plugin
module.exports = (BasePlugin) ->
    jsdom = require("jsdom")
    wsd = require("websequencediagrams")
    fs = require('fs')
    cheerio = require('cheerio')
    crypto = require('crypto')

    # *** Helpers ***
    String.prototype.replaceBetween = (start, end, what) ->
        this.substring(0, start) + what + this.substring(end)

    PREFORMATTED_TAGS = ["code", "tt"]
    is_preformatted = (content, id) ->
        doc = cheerio.load(content)
        node = doc('code:contains("#{id}"), tt:contains("#{id}")')
        node.length>0

    process_tag = (tag) ->
        if tag.match(/^_TOC_$/)
            "[[#{tag}]]"
        else if tag.match(/^_$/)
            "<div class='clearfloats'></div>"
        else if html = process_include_tag(tag)
            html
        else if html = process_image_tag(tag)
            html
        else if html = process_file_link_tag(tag)
            html
        else if html = process_page_link_tag(tag)
            html
        else
            "[[#{tag}]]"

    process_include_tag = (tag) -> null
    process_image_tag = (tag) -> null
    parse_image_tag_options = (tag) -> null
    process_file_link_tag = (tag) -> null
    process_page_link_tag = (tag) ->
        tags = tag.split('|')
        if tags.length == 1
            name = tags[0].trim()
            link = encodeURIComponent(name)
            "<a href='#{link}'>#{name}</a>"
        else if tags.length == 2
            name = tags[0].trim()
            link = encodeURIComponent(tags[1].trim())
            "<a class='internal' href='#{link}'>#{name}</a>"
        else
            null

    # Define Plugin
    class WritingCandyPlugin extends BasePlugin
        # Plugin name
        name: 'WritingCandy'
        renderDocument: (opts, next) ->
            {extension, file, content} = opts

            if file.type is 'document' and extension is 'html'

                # 1. Fetch Remote Code
                # 2. Double-square-brackets
                # 2-1 Put placeholders
                map = {}
                content = content.replace(/(.?)\[\[(.+?)\]\]([^\[]?)/gm, (match, $1, $2, $3)->
                    if $1 == "'" and $3 != "'"
                        "[[#{$2}]]#{$3}"
                    else if $2.indexOf('][')>=0

                        if $2.slice(0,5)=='file:'
                            pre = $1
                            post = $3
                            parts = $2.split('][')
                            parts[0].replaceBetween(0,5,"")
                            link = "#{parts[1]}|#{parts[0].replace(/\.org/,'')}"
                            id = crypto.createHash('sha1').update(link).digest('hex')
                            map[id] = link
                            "#{pre}#{id}#{post}"
                        else
                            match
                    else
                        id = crypto.createHash('sha1').update($2).digest('hex')
                        map[id] = $2
                        "#{$1}#{id}#{$3}"
                )


                # 2-2 Process tags
                for id, tag of map
                    if is_preformatted(content,id)
                        #if opts.document.basename=='test'
                        content = content.replace(id, "[[#{tag}]]")
                    else
                        #if opts.document.basename=='test'
                        content = content.replace(id, process_tag(tag).replace('%2F','/'))
                        # Twitter @id link
                        # 5. Web-sequence-diagram http://www.websequencediagrams.com/index.php"
                        content = content.replace(
                            /^\{\{\{\{\{\{ ?(.+?)\r?\n(.+?)\r?\n\}\}\}\}\}\}\r?$/gm
                            , (match, style, code) ->
                                wsd.diagram(code, style, "png", (err, buf, typ) ->
                                    if err
                                        console.error(err)
                                    else
                                        console.log("Received MIME type:", typ)
                                        fs.writeFile("my.png", buf)
                                )

                                "<img src='wsd' />"
                        )

                # 3. TOC : https://github.com/gollum/gollum-lib/blob/master/lib/gollum-lib/filter/toc.rb
                ###
                toc = []
                parsed = cheerio.load(content)
                parsed('h1,h2,h3,h4,h5,h6').each( (index, element)->
                    name = parsed(this).contents().replace(' ','-').replace('"','%22')
                    # h3 -> 3
                    level = this[0].name.replace(/[hH]/,'')
                    # Add Anchor
                    this.append("{<a class='anchor' id='#{name}' href='\##{name}'></a>")

                    toc.append()

                    ...
                ###

                opts.content = content
                return next()
            else
                return next()