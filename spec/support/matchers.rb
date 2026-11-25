# `change` の否定版。「Aは増えるが、Bは増えない」のような複合の期待に使う。
RSpec::Matchers.define_negated_matcher :not_change, :change
