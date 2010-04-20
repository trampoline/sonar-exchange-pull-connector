require 'tmail'

# This monkeypatch fixes SONAR bug # 648. It appears that TMail only unquotes or
# decodes the body and the subject of an email. According to RFC2047
# (http://www.faqs.org/rfcs/rfc2047.html) all header fields should be
# decoded.
module TMail
  class StructuredHeader < HeaderField
    def do_parse
      quote_boundary
      s = Unquoter.unquote_and_convert_to(@body, 'utf-8')
      obj = Parser.parse(self.class::PARSE_TYPE, s, @comments)
      set obj if obj
    end
  end
  
  class Address 
    def Address.parse( str )
      str = TMail::Unquoter.unquote_and_convert_to(str, 'utf-8')
      Parser.parse :ADDRESS, special_quote_address(str)
    end
  end

  class Mail
    def each_part_recursive( &block )
      parts().each do |part|
        block.call( part )

        if part.content_type =~  %r[\Amultipart/]
          part.each_part_recursive( &block )
        end
      end
    end
  end
end
