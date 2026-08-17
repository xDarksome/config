export def object [obj: record, schema: record] {
    let obj_fields = ($obj | columns | sort)
    let schema_fields = ($schema | columns | sort)

    if $obj_fields != $schema_fields {
        error make {
            msg: $"invalid fields: expected ($schema_fields), got ($obj_fields)"
        }
    }

    for field in ($schema | columns) {
        let rule = ($schema | get $field)
        let value = ($obj | get $field)

        validate-field $field $value $rule
    }

    $obj
}

export def type [name: string] {
    { kind: type, type: $name }
}

export def enum [values: list] {
    { kind: enum, values: $values }
}

export def range [range: range] {
    { kind: range, range: $range }
}

export def value [value: any] {
    { kind: value, value: $value }
}

export def min-len [n: int] {
    { kind: min-len, value: $n }
}

export def max-len [n: int] {
    { kind: max-len, value: $n }
}

export def len-range [range: range] {
    { kind: len-range, range: $range }
}

def validate-field [field: string, value: any, rule: record] {
    if $value == null {
        return
    }

    match $rule.kind {
        type => {
            let actual = ($value | describe)

            if $actual != $rule.type {
                error make {
                    msg: $"field '($field)': expected type ($rule.type), got ($actual)"
                }
            }
        }

        enum => {
            if $value not-in $rule.values {
                error make {
                    msg: $"field '($field)': expected one of ($rule.values), got ($value)"
                }
            }
        }

        range => {
            if ($value | describe) != "int" {
                error make {
                    msg: $"field '($field)': expected int in range ($rule.range), got ($value | describe)"
                }
            }

            if $value not-in $rule.range {
                error make {
                    msg: $"field '($field)': expected value in ($rule.range), got ($value)"
                }
            }
        }

         value => {
            if $value != $rule.value {
                error make {
                    msg: $"field '($field)': expected ($rule.value), got ($value)"
                }
            }
         }

        min-len => {
            let actual = ($value | length)

            if $actual < $rule.value {
                error make {
                    msg: $"field '($field)': expected at least ($rule.value) elements, got ($actual)"
                }
            }
        }

        max-len => {
            let actual = ($value | length)

            if $actual > $rule.value {
                error make {
                    msg: $"field '($field)': expected at most ($rule.value) elements, got ($actual)"
                }
            }
        }

        len-range => {
            let actual = ($value | length)

            if $actual not-in $rule.range {
                error make {
                    msg: $"field '($field)': expected length in ($rule.range), got ($actual)"
                }
            }
        }

        _ => {
            error make {
                msg: $"field '($field)': unknown validator kind ($rule.kind)"
            }
        }
    }
}
