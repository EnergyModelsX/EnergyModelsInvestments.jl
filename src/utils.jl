"""
    has_capacity(i)

Check if node i should be used for capacity calculations, i.e.
    * is not Availability
    * has capacity

    TODO: Move to EMB?
"""
function has_capacity(i)
    ~isa(i, Availability) && 
    (
        true || # TODO: Implement these properties (or similar)
        has_property(i, :ExistingCapacity) ||
        has_property(i, :MaxAddCapacity) ||
        has_property(i, :MaxTotalCapacity) ||
        has_property(i, :UnitCapacity   
    )
end