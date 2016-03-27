class RVar

    attr_reader :value

    def initialize value
        @value = value
        @blocks = []
    end

    def value= value
        if value != @value
            @value = value
            @blocks.each {|b| b.call}
        end
    end

    def add block
        @blocks << block
    end
end

def reactive(*args, &block)
    args.each {|v| v.add block}
    block.call
    # return a ticket that will be used to remove block from rvar
end

#a = RVar.new 5

#reactive(a) {puts a.value}
#a.value = 8