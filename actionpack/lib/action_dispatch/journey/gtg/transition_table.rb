# frozen_string_literal: true

require "action_dispatch/journey/nfa/dot"

module ActionDispatch
  module Journey # :nodoc:
    module GTG # :nodoc:
      class TransitionTable # :nodoc:
        include Journey::NFA::Dot

        attr_reader :memos

        def initialize
          @regexp_states = {}
          @string_states = {}
          @accepting     = {}
          @memos         = Hash.new { |h, k| h[k] = [] }
        end

        def add_accepting(state)
          @accepting[state] = true
        end

        def accepting_states
          @accepting.keys
        end

        def accepting?(state)
          @accepting[state]
        end

        def add_memo(idx, memo)
          @memos[idx] << memo
        end

        def memo(idx)
          @memos[idx]
        end

        def eclosure(t)
          Array(t)
        end

        def move(t, a)
          return [] if t.empty?

          regexps = []

          t.map { |s|
            if states = @regexp_states[s]
              regexps.concat states.map { |re, v| re.match?(a) ? v : nil }
            end

            if states = @string_states[s]
              states[a]
            end
          }.compact.concat regexps
        end

        def as_json(options = nil)
          simple_regexp = Hash.new { |h, k| h[k] = {} }

          @regexp_states.each do |from, hash|
            hash.each do |re, to|
              simple_regexp[from][re.source] = to
            end
          end

          {
            regexp_states: simple_regexp,
            string_states: @string_states,
            accepting:     @accepting
          }
        end

        def to_svg
          svg = IO.popen("dot -Tsvg", "w+") { |f|
            f.write(to_dot)
            f.close_write
            f.readlines
          }
          3.times { svg.shift }
          svg.join.sub(/width="[^"]*"/, "").sub(/height="[^"]*"/, "")
        end

        def visualizer(paths, title = "FSM")
          viz_dir   = File.join __dir__, "..", "visualizer"
          fsm_js    = File.read File.join(viz_dir, "fsm.js")
          fsm_css   = File.read File.join(viz_dir, "fsm.css")
          erb       = File.read File.join(viz_dir, "index.html.erb")
          states    = "function tt() { return #{to_json}; }"

          fun_routes = paths.sample(3).map do |ast|
            ast.map { |n|
              case n
              when Nodes::Symbol
                case n.left
                when ":id" then rand(100).to_s
                when ":format" then %w{ xml json }.sample
                else
                  "omg"
                end
              when Nodes::Terminal then n.symbol
              else
                nil
              end
            }.compact.join
          end

          stylesheets = [fsm_css]
          svg         = to_svg
          javascripts = [states, fsm_js]

          fun_routes  = fun_routes
          stylesheets = stylesheets
          svg         = svg
          javascripts = javascripts

          require "erb"
          template = ERB.new erb
          template.result(binding)
        end

        def []=(from, to, sym)
          to_mappings = states_hash_for(sym)[from] ||= {}
          to_mappings[sym] = to
        end

        def states
          ss = @string_states.keys + @string_states.values.flat_map(&:values)
          rs = @regexp_states.keys + @regexp_states.values.flat_map(&:values)
          (ss + rs).uniq
        end

        def transitions
          @string_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          } + @regexp_states.flat_map { |from, hash|
            hash.map { |s, to| [from, s, to] }
          }
        end

        private
          def states_hash_for(sym)
            case sym
            when String
              @string_states
            when Regexp
              @regexp_states
            else
              raise ArgumentError, "unknown symbol: %s" % sym.class
            end
          end
      end
    end
  end
end
