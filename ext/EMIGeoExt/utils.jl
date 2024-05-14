"""
    EMI.get_var_inst(m, prefix::Symbol, type::EMG.TransmissionMode)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
EMI.get_var_inst(m, prefix::Symbol, type::EMG.TransmissionMode)  = m[Symbol(prefix)][type, :]
