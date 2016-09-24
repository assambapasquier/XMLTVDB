=head1 TVListings Known Bugs

=over 4

=item DST Switches

TVListings doesn't always deal properly with showing the grid when it
crosses a DST switch.  This is cause by a bug in the PostgreSQL date_trunc()
function.

=back

=cut